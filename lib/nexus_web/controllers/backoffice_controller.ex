defmodule NexusWeb.BackofficeController do
  use NexusWeb, :controller

  alias Nexus.Identity.Queries.UserQuery

  @doc """
  Initiates a God-Mode impersonation session.
  This action is protected by the `require_system_admin` plug in the router.
  """
  def impersonate(conn, %{"id" => user_id}) do
    # Fetch the target user we want to impersonate
    case UserQuery.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "User not found.")
        |> redirect(to: ~p"/backoffice")

      user ->
        # Drop the admin into the target user's session scope, but securely flagged
        conn
        |> put_session(:impersonated_user_id, user.id)
        |> put_flash(:info, "Impersonating #{user.email}. Read-Only Mode Active.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  @doc """
  Terminates an active impersonation session and returns the admin to the Backoffice.
  """
  def end_impersonation(conn, _params) do
    conn
    |> delete_session(:impersonated_user_id)
    |> put_flash(:info, "Impersonation ended.")
    |> redirect(to: ~p"/backoffice")
  end
end
