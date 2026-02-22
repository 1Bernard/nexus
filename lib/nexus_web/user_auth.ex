defmodule NexusWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Nexus.Repo
  alias Nexus.Identity.Projections.User

  # Plug pipeline to require authentication
  def require_authenticated_user(conn, _opts) do
    if get_session(conn, :user_id) do
      conn
    else
      conn
      |> redirect(to: "/")
      |> halt()
    end
  end

  # Plug pipeline to redirect already authenticated users away from login
  def redirect_if_user_is_authenticated(conn, _opts) do
    if get_session(conn, :user_id) do
      conn
      |> redirect(to: "/dashboard")
      |> halt()
    else
      conn
    end
  end

  # LiveView on_mount to protect LiveViews
  def on_mount(:mount_current_user, _params, session, socket) do
    if user_id = session["user_id"] do
      case Repo.get(User, user_id) do
        nil ->
          {:halt, Phoenix.LiveView.redirect(socket, to: "/")}

        user ->
          socket =
            socket
            |> Phoenix.Component.assign(:current_user_id, user_id)
            |> Phoenix.Component.assign(:current_user, user)
            |> Phoenix.Component.assign(:session_id, String.slice(String.upcase(user_id), 0, 8))

          {:cont, socket}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  # LiveView on_mount to redirect away from login
  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    if session["user_id"] do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
    else
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_user_id, nil)
       |> Phoenix.Component.assign(:current_user, nil)}
    end
  end
end
