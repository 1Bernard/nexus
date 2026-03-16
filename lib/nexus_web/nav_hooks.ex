defmodule NexusWeb.NavHooks do
  @moduledoc """
  Global LiveView hooks for navigation and system-wide reactive data.
  Attaches event and info interceptors via `attach_hook/4` so that
  command palette search, notification actions, and PubSub messages
  are handled globally across all authenticated LiveViews.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias Nexus.CrossDomain

  def on_mount(:default, _params, session, socket) do
    user_id = session["user_id"]
    org_id = session["org_id"]

    if connected?(socket) and user_id do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "notifications:#{org_id}")
      Phoenix.PubSub.subscribe(Nexus.PubSub, "notifications:user:#{user_id}")
      Phoenix.PubSub.subscribe(Nexus.PubSub, "unread_count:user:#{user_id}")
    end

    notifications =
      if user_id do
        CrossDomain.list_notifications(org_id, user_id, 10)
      else
        []
      end

    {:cont,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, Enum.count(notifications, &is_nil(&1.read_at)))
     |> assign(:command_palette_open, false)
     |> assign(:command_results, [])
     |> attach_hook(:nav_handle_event, :handle_event, &handle_nav_event/3)
     |> attach_hook(:nav_handle_info, :handle_info, &handle_nav_info/2)}
  end

  # --- Global Event Interceptors ---

  defp handle_nav_event("mark-read", %{"id" => id}, socket) do
    Nexus.App.dispatch(%Nexus.CrossDomain.Commands.MarkNotificationRead{
      id: id,
      org_id: socket.assigns.current_user.org_id,
      user_id: socket.assigns.current_user.id
    })

    {:halt, socket}
  end

  defp handle_nav_event("toggle_command_palette", _params, socket) do
    new_state = !socket.assigns.command_palette_open

    socket =
      socket
      |> assign(:command_palette_open, new_state)
      |> then(fn s ->
        if new_state, do: push_event(s, "focus_search", %{}), else: assign(s, :command_results, [])
      end)

    {:halt, socket}
  end

  defp handle_nav_event("close_command_palette", _params, socket) do
    {:halt,
     socket
     |> assign(:command_palette_open, false)
     |> assign(:command_results, [])}
  end

  defp handle_nav_event("command_palette_search", %{"query" => query}, socket) do
    org_id = resolve_search_org_id(socket)
    results = CrossDomain.search(org_id, String.trim(query))

    {:halt, assign(socket, :command_results, results)}
  end

  defp handle_nav_event(_event, _params, socket) do
    {:cont, socket}
  end

  # --- Helpers ---

  defp resolve_search_org_id(socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) -> :all
      user.role == "system_admin" -> :all
      true -> user.org_id
    end
  end

  # --- Real-Time PubSub Interceptors ---

  defp handle_nav_info({:notification_created, notification}, socket) do
    notifications = [notification | socket.assigns.notifications] |> Enum.take(10)

    {:halt,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, socket.assigns.unread_count + 1)}
  end

  defp handle_nav_info({:notification_read, id}, socket) do
    notifications =
      Enum.map(socket.assigns.notifications, fn
        %{id: ^id} = notification -> %{notification | read_at: DateTime.utc_now()}
        notification -> notification
      end)

    {:halt,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, max(0, socket.assigns.unread_count - 1))}
  end

  defp handle_nav_info({:unread_count, count}, socket) do
    {:halt, assign(socket, :unread_count, count)}
  end

  defp handle_nav_info(_msg, socket), do: {:cont, socket}
end
