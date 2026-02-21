defmodule NexusWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

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
      {:cont, Phoenix.Component.assign(socket, :current_user_id, user_id)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  # LiveView on_mount to redirect away from login
  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    if session["user_id"] do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
    else
      {:cont, Phoenix.Component.assign(socket, :current_user_id, nil)}
    end
  end
end
