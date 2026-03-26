defmodule Nexus.Identity.Projectors.UserProjector do
  @moduledoc """
  Handles User lifecycle events (role, status) and updates the User projection.
  Decoupled for scalability (Rule 3).
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Identity.Projectors.UserProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.{
    UserRoleChanged,
    UserStatusChanged,
    SettingsUpdated,
    SessionStarted,
    SessionExpired,
    UserRoleRevoked
  }

  alias Nexus.Identity.Projections.{User, UserSettings, UserSession}
  import Ecto.Query

  project(%UserRoleChanged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_roles,
      from(u in User, where: u.id == ^event.user_id),
      # Replacing the array with the new role as a single-item list
      set: [roles: [event.role], updated_at: Nexus.Schema.utc_now()]
    )
  end)

  project(%UserRoleRevoked{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.run(:revoke_role, fn repo, _ ->
      user = repo.get!(User, event.user_id)
      new_roles = Enum.reject(user.roles, &(&1 == event.role))

      from(u in User, where: u.id == ^event.user_id)
      |> repo.update_all(set: [roles: new_roles, updated_at: Nexus.Schema.utc_now()])

      {:ok, nil}
    end)
  end)

  project(%UserStatusChanged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_status,
      from(u in User, where: u.id == ^event.user_id),
      set: [
        status: event.status,
        updated_at: Nexus.Schema.utc_now()
      ]
    )
  end)

  project(%SettingsUpdated{} = event, _metadata, fn multi ->
    updates =
      [
        locale: event.locale,
        timezone: event.timezone,
        notifications_enabled: event.notifications_enabled,
        updated_at: event.updated_at
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    multi
    |> Ecto.Multi.update_all(
      :update_settings,
      from(s in UserSettings, where: s.user_id == ^event.user_id),
      set: updates
    )
  end)

  project(%SessionStarted{} = event, _metadata, fn multi ->
    session_data = %{
      id: event.session_id,
      org_id: event.org_id,
      user_id: event.user_id,
      session_token: event.session_token,
      user_agent: event.user_agent,
      ip_address: event.ip_address,
      last_active_at: event.started_at,
      is_expired: false
    }

    multi
    |> Ecto.Multi.insert(:insert_session, UserSession.changeset(%UserSession{}, session_data))
  end)

  project(%SessionExpired{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :expire_session,
      from(s in UserSession, where: s.id == ^event.session_id),
      set: [is_expired: true, updated_at: event.expired_at]
    )
  end)
end
