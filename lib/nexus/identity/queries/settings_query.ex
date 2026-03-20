defmodule Nexus.Identity.Queries.SettingsQuery do
  @moduledoc """
  Read-model queries for user preferences and active sessions.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Identity.Projections.{UserSettings, UserSession}
  alias Nexus.Types

  @doc """
  Fetches a user's settings by their user_id and org_id.
  """
  @spec get_settings(Types.org_id(), Types.user_id()) :: UserSettings.t() | nil
  def get_settings(org_id, user_id) do
    from(s in UserSettings, where: s.org_id == ^org_id and s.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Lists active (non-expired) sessions for a user, scoped by organization.
  """
  @spec list_active_sessions(Types.org_id(), Types.user_id()) :: [UserSession.t()]
  def list_active_sessions(org_id, user_id) do
    from(s in UserSession,
      where: s.org_id == ^org_id and s.user_id == ^user_id and s.is_expired == false,
      order_by: [desc: s.last_active_at]
    )
    |> Repo.all()
  end

  @doc """
  Fetches a specific session by its ID, scoped by organization.
  """
  @spec get_session(Types.org_id(), Types.binary_id()) :: UserSession.t() | nil
  def get_session(org_id, session_id) do
    from(s in UserSession, where: s.org_id == ^org_id and s.id == ^session_id)
    |> Repo.one()
  end
end
