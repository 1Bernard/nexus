defmodule NexusWeb.Admin.UserLive.Index do
  @moduledoc """
  LiveView for system administrators to list, search, and manage all platform users.
  """
  use NexusWeb, :live_view

  alias Nexus.Identity.Queries.UserQuery
  alias NexusWeb.Presence

  @presence_topic "org_presence"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to organizational presence
      Phoenix.PubSub.subscribe(
        Nexus.PubSub,
        "#{@presence_topic}:#{socket.assigns.current_user.org_id}"
      )

      # Track current user's presence
      Presence.track(
        self(),
        "#{@presence_topic}:#{socket.assigns.current_user.org_id}",
        socket.assigns.current_user.id,
        %{
          display_name: socket.assigns.current_user.display_name,
          email: socket.assigns.current_user.email,
          role: socket.assigns.current_user.role,
          online_at: inspect(System.system_time(:second))
        }
      )
    end

    socket =
      socket
      |> assign(:page_title, "User Management")
      |> assign(:search, "")
      |> assign(:role_filter, "all")
      |> assign(:active_users, [])
      |> assign(:show_invite_modal, false)
      |> assign(:generated_invite_url, nil)
      |> assign(:invite_role, "trader")
      |> assign(:editing_user, nil)
      |> assign(:editing_role, nil)
      |> fetch_users()
      |> handle_presence_sync()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "User Management")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign(:search, search)
      |> assign(:cursor_before, nil)
      |> assign(:cursor_after, nil)
      |> fetch_users()

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate-invite", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: true, generated_invite_url: nil)}
  end

  @impl true
  def handle_event("close-invite-modal", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: false)}
  end

  @impl true
  def handle_event("set-invite-role", %{"role" => role}, socket) do
    {:noreply, assign(socket, invite_role: role)}
  end

  @impl true
  def handle_event(
        "confirm-generate-invite",
        %{"role" => role, "email" => email, "display_name" => name},
        socket
      ) do
    # In a real system, we'd store the invited detail or send an email
    token =
      Phoenix.Token.sign(NexusWeb.Endpoint, "user_invitation", %{
        org_id: socket.assigns.current_user.org_id,
        role: role,
        invited_by: socket.assigns.current_user.id,
        email: email,
        display_name: name
      })

    url = NexusWeb.Endpoint.url() <> "/auth/invite/" <> token

    {:noreply, assign(socket, generated_invite_url: url, invite_role: role)}
  end

  @impl true
  def handle_event("edit-user", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, fn u -> u.id == id end)
    {:noreply, assign(socket, editing_user: user, editing_role: user.role)}
  end

  @impl true
  def handle_event("close-edit-modal", _params, socket) do
    {:noreply, assign(socket, editing_user: nil)}
  end

  @impl true
  def handle_event("set-editing-role", %{"role" => role}, socket) do
    {:noreply, assign(socket, editing_role: role)}
  end

  @impl true
  def handle_event("update-user-role", %{"role" => role, "user_id" => user_id}, socket) do
    command = %Nexus.Identity.Commands.ChangeUserRole{
      user_id: user_id,
      role: role,
      actor_id: socket.assigns.current_user.id,
      changed_at: DateTime.utc_now()
    }

    # Dispatch command to the application (Commanded)
    case Nexus.App.dispatch(command) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "User role updated successfully")
         |> assign(editing_user: nil)
         |> fetch_users()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update role: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("filter-role", %{"role" => role}, socket) do
    socket =
      socket
      |> assign(:role_filter, role)
      |> assign(:cursor_before, nil)
      |> assign(:cursor_after, nil)
      |> fetch_users()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_limit", %{"limit" => limit}, socket) do
    limit_int = String.to_integer(limit)

    socket =
      socket
      |> assign(:limit, limit_int)
      |> assign(:cursor_before, nil)
      |> assign(:cursor_after, nil)
      |> fetch_users()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_page", %{"direction" => "next"}, socket) do
    next_cursor = socket.assigns.page_meta[:next_cursor]

    socket =
      socket
      |> assign(:cursor_after, next_cursor)
      |> assign(:cursor_before, nil)
      |> fetch_users()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_page", %{"direction" => "prev"}, socket) do
    prev_cursor = socket.assigns.page_meta[:prev_cursor]

    socket =
      socket
      |> assign(:cursor_before, prev_cursor)
      |> assign(:cursor_after, nil)
      |> fetch_users()

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, handle_presence_sync(socket)}
  end

  # --- Internal Helpers ---

  defp fetch_users(socket) do
    limit = socket.assigns[:limit] || 25

    query_params = %{
      "search" => socket.assigns.search,
      "role" => socket.assigns.role_filter,
      "limit" => limit,
      "cursor_after" => socket.assigns[:cursor_after],
      "cursor_before" => socket.assigns[:cursor_before]
    }

    users_page = UserQuery.list_users_by_org(socket.assigns.current_user.org_id, query_params)
    total_count = UserQuery.total_users_count(socket.assigns.current_user.org_id)

    # Convert the page struct into assigned values. If users_page is a list (legacy support), mock the page_meta
    {users, page_meta} =
      if is_struct(users_page, Scrivener.Page) or
           (is_map(users_page) and Map.has_key?(users_page, :entries)) do
        {users_page.entries,
         %{
           next_cursor: users_page.metadata.after,
           prev_cursor: users_page.metadata.before
         }}
      else
        {users_page, %{next_cursor: nil, prev_cursor: nil}}
      end

    datagrid_params = %{
      search: socket.assigns.search,
      role: socket.assigns.role_filter,
      limit: limit,
      cursor_after: page_meta.next_cursor,
      cursor_before: page_meta.prev_cursor
    }

    socket
    |> assign(:users, users)
    |> assign(:total_count, total_count)
    |> assign(:page_meta, page_meta)
    |> assign(:datagrid_params, datagrid_params)
  end

  defp handle_presence_sync(socket) do
    presences = Presence.list("#{@presence_topic}:#{socket.assigns.current_user.org_id}")

    active_users =
      Enum.map(presences, fn {user_id, %{metas: metas}} ->
        meta = List.first(metas)
        Map.put(meta, :id, user_id)
      end)

    assign(socket, active_users: active_users)
  end
end
