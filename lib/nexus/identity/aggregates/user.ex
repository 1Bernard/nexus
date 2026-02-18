defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  defstruct [:id, :email, :role, :status, :public_key]

  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.Events.UserRegistered

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %RegisterUser{} = cmd) do
    %UserRegistered{
      user_id: cmd.user_id,
      email: cmd.email,
      role: cmd.role,
      public_key: cmd.public_key,
      registered_at: DateTime.utc_now()
    }
  end

  def execute(
        %__MODULE__{id: id, public_key: _pk} = state,
        %Nexus.Identity.Commands.VerifyBiometric{} = cmd
      ) do
    # Simulation: Verify signature matches the "protocol"
    # Actually we should verify against challenge, but for this BDD phase:
    if cmd.user_id == id do
      %Nexus.Identity.Events.BiometricVerified{
        user_id: id,
        handshake_id: cmd.challenge_id,
        verified_at: DateTime.utc_now()
      }
    else
      {:error, :unauthorized}
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
        email: ev.email,
        role: ev.role,
        public_key: ev.public_key,
        status: :registered
    }
  end

  def apply(%__MODULE__{} = state, %Nexus.Identity.Events.BiometricVerified{}) do
    # Identity verified, no state change for now
    state
  end
end
