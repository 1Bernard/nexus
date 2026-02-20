defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  defstruct [:id, :display_name, :role, :status, :cose_key, :credential_id]

  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.Events.UserRegistered

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %RegisterUser{} = cmd) do
    # 1. Retrieve the challenge from the store (this would happen in the controller usually,
    # but since this is an aggregate we might need to pass it in or verify it here if we trust the caller)
    # Actually, Commanded best practice is to verify in the controller/handler and pass verified data.
    # However, to keep it "Internal" to the aggregate logic:

    case Nexus.Identity.AuthChallengeStore.pop_challenge(cmd.user_id) do
      {:ok, challenge} ->
        case Nexus.Identity.WebAuthn.register(
               cmd.attestation_object,
               cmd.client_data_json,
               challenge
             ) do
          {:ok, {auth_data, _result}} ->
            cose_key = auth_data.attested_credential_data.credential_public_key
            credential_id = auth_data.attested_credential_data.credential_id

            %UserRegistered{
              user_id: cmd.user_id,
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
        %__MODULE__{id: id, cose_key: cose_key_bin} = _state,
        %Nexus.Identity.Commands.VerifyBiometric{} = cmd
      ) do
    case Nexus.Identity.AuthChallengeStore.pop_challenge(cmd.challenge_id) do
      {:ok, challenge} ->
        _cose_key = :erlang.binary_to_term(Base.decode64!(cose_key_bin))

        # Wax.authenticate(raw_id, authenticator_data, sig, client_data_json, challenge)
        # Note: raw_id must match the registered credential_id
        case Nexus.Identity.WebAuthn.authenticate(
               cmd.raw_id,
               cmd.authenticator_data,
               cmd.signature,
               cmd.client_data_json,
               challenge
             ) do
          {:ok, _} ->
            %Nexus.Identity.Events.BiometricVerified{
              user_id: id,
              handshake_id: cmd.challenge_id,
              verified_at: DateTime.utc_now()
            }

          {:error, reason} ->
            {:error, {:webauthn_error, reason}}
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
        display_name: ev.display_name,
        role: ev.role,
        cose_key: ev.cose_key,
        credential_id: ev.credential_id,
        status: :registered
    }
  end

  def apply(%__MODULE__{} = state, %Nexus.Identity.Events.BiometricVerified{}) do
    # Identity verified, no state change for now
    state
  end
end
