defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  defstruct [:id, :org_id, :email, :display_name, :role, :status, :cose_key, :credential_id]

  alias Nexus.Identity.Commands.{
    RegisterUser,
    RegisterSystemAdmin,
    VerifyBiometric,
    VerifyStepUp,
    ChangeUserRole
  }

  alias Nexus.Identity.Events.{BiometricVerified, UserRegistered, StepUpVerified, UserRoleChanged}

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
      registered_at: cmd.registered_at
    }
  end

  def execute(%__MODULE__{id: _exists}, %RegisterSystemAdmin{}) do
    {:error, :already_registered}
  end

  def execute(%__MODULE__{id: nil}, %RegisterUser{} = cmd) do
    %UserRegistered{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      email: cmd.email,
      display_name: cmd.display_name,
      role: cmd.role,
      cose_key: cmd.cose_key,
      credential_id: cmd.credential_id,
      registered_at: cmd.registered_at
    }
  end

  def execute(%__MODULE__{id: nil}, %VerifyBiometric{}) do
    {:error, :unregistered_user}
  end

  def execute(%__MODULE__{id: id, status: :registered}, %VerifyBiometric{} = cmd) do
    %BiometricVerified{
      user_id: id,
      org_id: cmd.org_id,
      handshake_id: cmd.challenge_id,
      verified_at: cmd.verified_at
    }
  end

  def execute(%__MODULE__{id: nil}, %VerifyStepUp{}) do
    {:error, :unregistered_user}
  end

  def execute(%__MODULE__{id: id, status: :registered}, %VerifyStepUp{} = cmd) do
    %StepUpVerified{
      user_id: id,
      org_id: cmd.org_id,
      action_id: cmd.action_id,
      verified_at: cmd.verified_at
    }
  end

  def execute(%__MODULE__{id: id}, %ChangeUserRole{} = cmd) when not is_nil(id) do
    %UserRoleChanged{
      user_id: cmd.user_id,
      role: cmd.role,
      actor_id: cmd.actor_id,
      changed_at: cmd.changed_at
    }
  end

  def execute(%__MODULE__{id: nil}, %ChangeUserRole{}) do
    {:error, :unregistered_user}
  end

  def execute(state, cmd) do
    {:error, {:unexpected_command, state, cmd}}
  end

  # --- State Transitions ---

  def apply(%__MODULE__{} = state, %UserRegistered{} = event) do
    %__MODULE__{
      state
      | id: event.user_id,
        org_id: event.org_id,
        email: event.email,
        display_name: event.display_name,
        role: event.role,
        cose_key: event.cose_key,
        credential_id: event.credential_id,
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

  def apply(%__MODULE__{} = state, %UserRoleChanged{} = event) do
    %__MODULE__{state | role: event.role}
  end
end
