defmodule Nexus.Identity.Queries.SettingsQuery do
  @moduledoc """
  Read-model queries for user preferences and active sessions.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Identity.Projections.{UserSettings, UserSession}

  @doc """
  Fetches a user's settings by their user_id.
  """
  def get_settings(user_id) do
    Repo.get_by(UserSettings, user_id: user_id)
  end

  @doc """
  Lists active (non-expired) sessions for a user.
  """
  def list_active_sessions(user_id) do
    from(s in UserSession,
      where: s.user_id == ^user_id and s.is_expired == false,
      order_by: [desc: s.last_active_at]
    )
    |> Repo.all()
  end

  @doc """
  Fetches a specific session by its ID.
  """
  def get_session(session_id) do
    Repo.get(UserSession, session_id)
  end
end
