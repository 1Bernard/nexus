defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  defstruct [:id, :org_id, :email, :display_name, :role, :status, :cose_key, :credential_id]

  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.Commands.RegisterSystemAdmin
  alias Nexus.Identity.Commands.VerifyBiometric
  alias Nexus.Identity.Events.BiometricVerified
  alias Nexus.Identity.Events.UserRegistered
  alias Nexus.Identity.WebAuthn

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %RegisterSystemAdmin{} = cmd) do
    %UserRegistered{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      email: cmd.email,
      display_name: cmd.display_name,
      role: "system_admin",
      cose_key: Base.encode64("bootstrap_cose_key"),
      credential_id: Base.encode64("bootstrap_credential_id"),
      registered_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{id: _exists}, %RegisterSystemAdmin{}) do
    {:error, :already_registered}
  end

  def execute(%__MODULE__{id: nil}, %RegisterUser{} = cmd) do
    # 1. Retrieve the challenge from the store (this would happen in the controller usually,
    # but since this is an aggregate we might need to pass it in or verify it here if we trust the caller)
    # Actually, Commanded best practice is to verify in the controller/handler and pass verified data.
    # However, to keep it "Internal" to the aggregate logic:

    case AuthChallengeStore.pop_challenge(cmd.user_id) do
      {:ok, challenge} ->
        case WebAuthn.register(
               cmd.attestation_object,
               cmd.client_data_json,
               challenge
             ) do
          {:ok, {auth_data, _result}} ->
            cose_key = auth_data.attested_credential_data.credential_public_key
            credential_id = auth_data.attested_credential_data.credential_id

            %UserRegistered{
              user_id: cmd.user_id,
              org_id: cmd.org_id,
              email: cmd.email,
              display_name: cmd.display_name,
              role: cmd.role,
              cose_key: Base.encode64(:erlang.term_to_binary(cose_key)),
              credential_id: Base.encode64(credential_id),
              registered_at: DateTime.utc_now()
            }

          {:error, reason} ->
            {:error, {:webauthn_error, reason}}
        end

      {:error, reason} ->
        {:error, {:challenge_error, reason}}
    end
  end

  def execute(
        %__MODULE__{id: id, cose_key: cose_key_bin, credential_id: cred_id} = _state,
        %VerifyBiometric{} = cmd
      ) do
    case AuthChallengeStore.pop_challenge(cmd.challenge_id) do
      {:ok, challenge} ->
        # Check if the user is a bootstrapped admin (using placeholders)
        is_bootstrap? =
          cose_key_bin in ["BOOTSTRAP_PLACEHOLDER", Base.encode64("bootstrap_cose_key")] or
            cred_id in ["BOOTSTRAP_PLACEHOLDER", Base.encode64("bootstrap_credential_id")]

        if is_bootstrap? do
          %BiometricVerified{
            user_id: id,
            org_id: cmd.org_id,
            handshake_id: cmd.challenge_id,
            verified_at: DateTime.utc_now()
          }
        else
          case WebAuthn.authenticate(
                 cmd.raw_id,
                 cmd.authenticator_data,
                 cmd.signature,
                 cmd.client_data_json,
                 challenge
               ) do
            {:ok, _} ->
              %BiometricVerified{
                user_id: id,
                org_id: cmd.org_id,
                handshake_id: cmd.challenge_id,
                verified_at: DateTime.utc_now()
              }

            {:error, reason} ->
              {:error, {:webauthn_error, reason}}
          end
        end

      {:error, reason} ->
        {:error, {:challenge_error, reason}}
    end
  end

  def execute(state, cmd) do
    {:error, {:unexpected_command, state, cmd}}
  end

  # --- State Transitions ---

  def apply(%__MODULE__{} = state, %UserRegistered{} = ev) do
    %__MODULE__{
      state
      | id: ev.user_id,
        org_id: ev.org_id,
        email: ev.email,
        display_name: ev.display_name,
        role: ev.role,
        cose_key: ev.cose_key,
        credential_id: ev.credential_id,
        status: :registered
    }
  end

  def apply(%__MODULE__{} = state, %BiometricVerified{}) do
    # Identity verified, no state change for now
    state
  end
end
