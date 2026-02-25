defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  defstruct [:id, :org_id, :email, :display_name, :role, :status, :cose_key, :credential_id]

  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.Commands.{RegisterUser, RegisterSystemAdmin, VerifyBiometric, VerifyStepUp}
  alias Nexus.Identity.Events.{BiometricVerified, UserRegistered, StepUpVerified}
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
    with {:ok, challenge} <- AuthChallengeStore.pop_challenge(cmd.user_id),
         {:ok, {auth_data, _result}} <-
           WebAuthn.register(cmd.attestation_object, cmd.client_data_json, challenge) do
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
    else
      {:error, reason} when is_atom(reason) -> {:error, {:challenge_error, reason}}
      {:error, reason} -> {:error, {:webauthn_error, reason}}
    end
  end

  def execute(
        %__MODULE__{id: id, cose_key: cose_key_bin, credential_id: cred_id} = _state,
        %VerifyBiometric{} = cmd
      ) do
    if bootstrap_user?(cose_key_bin, cred_id) do
      with {:ok, _challenge} <- AuthChallengeStore.pop_challenge(cmd.challenge_id) do
        %BiometricVerified{
          user_id: id,
          org_id: cmd.org_id,
          handshake_id: cmd.challenge_id,
          verified_at: DateTime.utc_now()
        }
      else
        {:error, reason} -> {:error, {:challenge_error, reason}}
      end
    else
      with {:ok, challenge} <- AuthChallengeStore.pop_challenge(cmd.challenge_id),
           {:ok, _} <-
             WebAuthn.authenticate(
               cmd.raw_id,
               cmd.authenticator_data,
               cmd.signature,
               cmd.client_data_json,
               challenge
             ) do
        %BiometricVerified{
          user_id: id,
          org_id: cmd.org_id,
          handshake_id: cmd.challenge_id,
          verified_at: DateTime.utc_now()
        }
      else
        {:error, reason} when is_atom(reason) -> {:error, {:challenge_error, reason}}
        {:error, reason} -> {:error, {:webauthn_error, reason}}
      end
    end
  end

  def execute(
        %__MODULE__{id: id, cose_key: cose_key_bin, credential_id: cred_id} = _state,
        %VerifyStepUp{} = cmd
      ) do
    if bootstrap_user?(cose_key_bin, cred_id) do
      with {:ok, _challenge} <- AuthChallengeStore.pop_challenge(cmd.challenge_id) do
        %StepUpVerified{
          user_id: id,
          org_id: cmd.org_id,
          action_id: cmd.action_id,
          verified_at: DateTime.utc_now()
        }
      else
        {:error, reason} -> {:error, {:challenge_error, reason}}
      end
    else
      with {:ok, challenge} <- AuthChallengeStore.pop_challenge(cmd.challenge_id),
           {:ok, _} <-
             WebAuthn.authenticate(
               cmd.raw_id,
               cmd.authenticator_data,
               cmd.signature,
               cmd.client_data_json,
               challenge
             ) do
        %StepUpVerified{
          user_id: id,
          org_id: cmd.org_id,
          action_id: cmd.action_id,
          verified_at: DateTime.utc_now()
        }
      else
        {:error, reason} when is_atom(reason) -> {:error, {:challenge_error, reason}}
        {:error, reason} -> {:error, {:webauthn_error, reason}}
      end
    end
  end

  def execute(state, cmd) do
    {:error, {:unexpected_command, state, cmd}}
  end

  # --- Private Helpers ---

  # Returns true when the user is a bootstrapped admin using placeholder credentials,
  # meaning real WebAuthn verification is skipped and we only validate the challenge exists.
  defp bootstrap_user?(cose_key_bin, cred_id) do
    cose_key_bin in ["BOOTSTRAP_PLACEHOLDER", Base.encode64("bootstrap_cose_key")] or
      cred_id in ["BOOTSTRAP_PLACEHOLDER", Base.encode64("bootstrap_credential_id")]
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

  def apply(%__MODULE__{} = state, %StepUpVerified{}) do
    # Step-up verified, no state change for now
    state
  end
end
