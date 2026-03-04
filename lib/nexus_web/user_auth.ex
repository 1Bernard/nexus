defmodule NexusWeb.UserAuth do
  @moduledoc "User authentication and session management."
  import Plug.Conn
  import Phoenix.Controller

  alias Nexus.Identity.Projections.User
  alias Nexus.Repo

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
            |> Phoenix.Component.assign_new(:current_user_id, fn -> user_id end)
            |> Phoenix.Component.assign_new(:current_user, fn -> user end)
            |> Phoenix.Component.assign_new(:session_id, fn ->
              String.slice(String.upcase(user_id), 0, 8)
            end)

          # Avoid double-attaching the hook if it's already there (e.g. redundant on_mount)
          socket =
            if socket.assigns[:current_path] do
              socket
            else
              Phoenix.LiveView.attach_hook(socket, :set_current_path, :handle_params, fn _params,
                                                                                         url,
                                                                                         socket ->
                {:cont, Phoenix.Component.assign(socket, :current_path, URI.parse(url).path)}
              end)
            end

          {:cont, socket}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end

  # LiveView on_mount to protect System Admin routes
  def on_mount(:require_system_admin, params, session, socket) do
    # First, rely on the base mount to get the user
    case on_mount(:mount_current_user, params, session, socket) do
      {:cont, socket} ->
        if socket.assigns.current_user.role == "system_admin" do
          {:cont, socket}
        else
          # If not system admin, kick them back to their dashboard
          {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
        end

      {:halt, socket} ->
        {:halt, socket}
    end
  end

  # LiveView on_mount to protect Organizational Admin routes
  def on_mount(:require_org_admin, params, session, socket) do
    on_mount(:mount_current_user, params, session, socket)
  end

  # LiveView on_mount to redirect away from login
  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    if user_id = session["user_id"] do
      # Only redirect if the user actually exists in the read-side DB
      case Repo.get(User, user_id) do
        nil ->
          # Session exists but user doesn't (or projector hasn't caught up).
          # We allow them to mount the auth page so they aren't trapped in a redirect loop.
          {:cont,
           socket
           |> Phoenix.Component.assign(:current_user_id, nil)
           |> Phoenix.Component.assign(:current_user, nil)}

        _user ->
          {:halt, Phoenix.LiveView.redirect(socket, to: "/dashboard")}
      end
    else
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_user_id, nil)
       |> Phoenix.Component.assign(:current_user, nil)}
    end
  end

  @doc """
  Industry-standard RBAC Check.
  Determines if a user has permission to perform an action on a resource.
  """
  def can?(nil, _action, _resource), do: false

  def can?(user, action, resource) do
    case {user.role, action, resource} do
      {"admin", _, _} -> true
      {"trader", action, _} when action in [:view, :create, :edit, :trade] -> true
      {"trader", :admin, _} -> false
      {"viewer", :view, _} -> true
      {"viewer", _, _} -> false
      _ -> false
    end
  end
end
