defmodule Nexus.Identity.Aggregates.User do
  @moduledoc """
  The Domain Aggregate for User Identity.
  Responsible for validating Biometric Handshakes and emitting Facts.
  """
  @derive Jason.Encoder
  defstruct [
    :id,
    :org_id,
    :email,
    :display_name,
    :role,
    :status,
    :cose_key,
    :credential_id,
    :settings,
    :sessions
  ]

  @type t :: %__MODULE__{}

  alias Nexus.Identity.Commands.{
    RegisterUser,
    RegisterSystemAdmin,
    VerifyBiometric,
    VerifyStepUp,
    ChangeUserRole,
    ChangeUserStatus,
    UpdateSettings,
    StartSession,
    ExpireSession,
    RevokeUserRole
  }

  alias Nexus.Identity.Events.{
    BiometricVerified,
    UserRegistered,
    StepUpVerified,
    UserRoleChanged,
    UserStatusChanged,
    SettingsUpdated,
    SessionStarted,
    SessionExpired,
    UserRoleRevoked
  }

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
      registered_at: cmd.registered_at,
      status: "active"
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
      role: cmd.role || "trader",
      cose_key: cmd.cose_key,
      credential_id: cmd.credential_id,
      registered_at: cmd.registered_at,
      status: "active"
    }
  end

  @spec execute(t(), struct()) :: term()

  def execute(%__MODULE__{id: _exists}, %RegisterUser{}) do
    {:error, :already_registered}
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
      org_id: cmd.org_id,
      role: cmd.role,
      actor_id: cmd.actor_id,
      changed_at: cmd.changed_at
    }
  end

  def execute(%__MODULE__{id: id}, %ChangeUserStatus{} = cmd) when not is_nil(id) do
    %UserStatusChanged{
      user_id: cmd.user_id,
      org_id: cmd.org_id,
      status: cmd.status,
      actor_id: cmd.actor_id,
      changed_at: cmd.changed_at
    }
  end

  def execute(%__MODULE__{id: id}, %UpdateSettings{} = cmd) when not is_nil(id) do
    %SettingsUpdated{
      user_id: id,
      org_id: cmd.org_id,
      locale: cmd.locale,
      timezone: cmd.timezone,
      notifications_enabled: cmd.notifications_enabled,
      updated_at: cmd.updated_at
    }
  end

  def execute(%__MODULE__{id: id}, %StartSession{} = cmd) when not is_nil(id) do
    %SessionStarted{
      user_id: id,
      org_id: cmd.org_id,
      session_id: cmd.session_id,
      session_token: cmd.session_token,
      user_agent: cmd.user_agent,
      ip_address: cmd.ip_address,
      started_at: cmd.started_at
    }
  end

  def execute(%__MODULE__{id: id}, %ExpireSession{} = cmd) when not is_nil(id) do
    %SessionExpired{
      user_id: id,
      org_id: cmd.org_id,
      session_id: cmd.session_id,
      expired_at: cmd.expired_at
    }
  end

  def execute(%__MODULE__{id: id, status: :registered}, %RevokeUserRole{} = cmd) when not is_nil(id) do
    %UserRoleRevoked{
      user_id: id,
      org_id: cmd.org_id,
      role: cmd.role,
      revoked_by: cmd.revoked_by,
      revoked_at: cmd.revoked_at
    }
  end

  def execute(%__MODULE__{id: nil}, %ChangeUserRole{}), do: {:error, :unregistered_user}
  def execute(%__MODULE__{id: nil}, %ChangeUserStatus{}), do: {:error, :unregistered_user}
  def execute(%__MODULE__{id: nil}, %UpdateSettings{}), do: {:error, :unregistered_user}
  def execute(%__MODULE__{id: nil}, %StartSession{}), do: {:error, :unregistered_user}
  def execute(%__MODULE__{id: nil}, %ExpireSession{}), do: {:error, :unregistered_user}

  def execute(state, cmd) do
    {:error, {:unexpected_command, state, cmd}}
  end

  # --- State Transitions ---

  @spec apply(t(), struct()) :: t()
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
        status: :registered,
        settings: %{
          locale: "en",
          timezone: "UTC",
          notifications_enabled: true
        },
        sessions: %{}
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

  def apply(%__MODULE__{} = state, %UserRoleRevoked{} = event) do
    # Only clear the role if it matches the revoked one (defensive)
    new_role = if state.role == event.role, do: "viewer", else: state.role
    %__MODULE__{state | role: new_role}
  end

  def apply(%__MODULE__{} = state, %UserStatusChanged{} = event) do
    status =
      case event.status do
        "active" -> :active
        "pending" -> :pending
        "suspended" -> :suspended
        _ -> :pending
      end

    %__MODULE__{state | status: status}
  end

  def apply(%__MODULE__{} = state, %SettingsUpdated{} = event) do
    %__MODULE__{
      state
      | settings: %{
          locale: event.locale,
          timezone: event.timezone,
          notifications_enabled: event.notifications_enabled
        }
    }
  end

  def apply(%__MODULE__{} = state, %SessionStarted{} = event) do
    sessions = state.sessions || %{}

    new_sessions =
      Map.put(sessions, event.session_id, %{
        user_agent: event.user_agent,
        ip_address: event.ip_address,
        started_at: event.started_at,
        last_active_at: event.started_at
      })

    %__MODULE__{state | sessions: new_sessions}
  end

  def apply(%__MODULE__{} = state, %SessionExpired{} = event) do
    sessions = state.sessions || %{}
    new_sessions = Map.delete(sessions, event.session_id)
    %__MODULE__{state | sessions: new_sessions}
  end
end
