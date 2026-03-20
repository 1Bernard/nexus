defmodule NexusWeb.Identity.SettingsLive do
  @moduledoc """
  User Settings LiveView for managing personal preferences and active security sessions.
  """
  use NexusWeb, :live_view

  alias Nexus.Identity.Queries.SettingsQuery
  alias Nexus.Identity.Projections.UserSettings
  alias Nexus.Identity.Commands.{UpdateSettings, ExpireSession}
  alias Nexus.App

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    settings =
      SettingsQuery.get_settings(user.org_id, user.id) ||
        %UserSettings{
          user_id: user.id,
          org_id: user.org_id,
          locale: "en",
          timezone: "UTC",
          notifications_enabled: true
        }

    sessions = SettingsQuery.list_active_sessions(user.org_id, user.id)

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:active_tab, :general)
      |> assign(:settings, settings)
      |> assign(:sessions, sessions)
      |> assign(:form, to_form(Map.from_struct(settings)))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab =
      case params["tab"] do
        "security" -> :security
        _ -> :general
      end

    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <.page_header title="Account Settings" subtitle="Manage your preferences and security sessions" />

      <div class="flex items-center gap-8 border-b border-white/5 mb-8">
        <button
          phx-click={JS.patch(~p"/settings?tab=general")}
          class={[
            "pb-4 text-xs font-bold uppercase tracking-[0.2em] transition-all relative",
            @active_tab == :general && "text-indigo-400",
            @active_tab != :general && "text-slate-500 hover:text-slate-300"
          ]}
        >
          General
          <%= if @active_tab == :general do %>
            <div class="absolute bottom-[-1px] left-0 right-0 h-0.5 bg-indigo-400 shadow-[0_0_8px_rgba(129,140,248,0.4)]">
            </div>
          <% end %>
        </button>

        <button
          phx-click={JS.patch(~p"/settings?tab=security")}
          class={[
            "pb-4 text-xs font-bold uppercase tracking-[0.2em] transition-all relative",
            @active_tab == :security && "text-indigo-400",
            @active_tab != :security && "text-slate-500 hover:text-slate-300"
          ]}
        >
          Security
          <%= if @active_tab == :security do %>
            <div class="absolute bottom-[-1px] left-0 right-0 h-0.5 bg-indigo-400 shadow-[0_0_8px_rgba(129,140,248,0.4)]">
            </div>
          <% end %>
        </button>
      </div>

      <%= if @active_tab == :general do %>
        <div class="max-w-2xl animate-in fade-in slide-in-from-bottom-2 duration-500">
          <.dark_card class="p-8">
            <h3 class="text-sm font-bold text-white mb-6 flex items-center gap-2">
              <span class="hero-cog-6-tooth w-4 h-4 text-indigo-400"></span>
              Localization & Preferences
            </h3>

            <.form
              for={@form}
              phx-change="validate_settings"
              phx-submit="save_settings"
              class="space-y-6"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <.label class="text-[10px] uppercase tracking-widest text-slate-500 mb-2 block">
                    Language (Locale)
                  </.label>
                  <.input
                    type="select"
                    field={@form[:locale]}
                    options={[
                      {"English", "en"},
                      {"French", "fr"},
                      {"German", "de"},
                      {"Japanese", "ja"}
                    ]}
                    class="bg-slate-900 border-white/10 text-white rounded-xl focus:ring-indigo-500 focus:border-indigo-500"
                  />
                </div>

                <div>
                  <.label class="text-[10px] uppercase tracking-widest text-slate-500 mb-2 block">
                    Timezone
                  </.label>
                  <.input
                    type="select"
                    field={@form[:timezone]}
                    options={[
                      {"UTC", "UTC"},
                      {"Europe/London", "Europe/London"},
                      {"Europe/Paris", "Europe/Paris"},
                      {"America/New_York", "America/New_York"},
                      {"Asia/Tokyo", "Asia/Tokyo"}
                    ]}
                    class="bg-slate-900 border-white/10 text-white rounded-xl focus:ring-indigo-500 focus:border-indigo-500"
                  />
                </div>
              </div>

              <div class="p-4 rounded-xl bg-indigo-500/5 border border-indigo-500/10 mb-6 flex items-start gap-3">
                <span class="hero-shield-check w-5 h-5 text-indigo-400 mt-0.5"></span>
                <div>
                  <p class="text-xs font-bold text-white uppercase tracking-wider">
                    Passkey Secured Account
                  </p>
                  <p class="text-[10px] text-slate-500 mt-1">
                    Your preferences are cryptographically bound to your hardware security key.
                  </p>
                </div>
              </div>

              <div class="flex items-center justify-between p-4 bg-white/[0.02] border border-white/5 rounded-xl">
                <div>
                  <p class="text-xs font-bold text-white">Notifications</p>
                  <p class="text-[10px] text-slate-500">Enable platform alerts and audit logs</p>
                </div>
                <.input
                  type="checkbox"
                  field={@form[:notifications_enabled]}
                  class="w-5 h-5 border-white/10 bg-slate-900 rounded-md text-indigo-500"
                />
              </div>

              <div class="pt-4">
                <.button
                  phx-disable-with="Syncing..."
                  class="w-full bg-indigo-600 hover:bg-indigo-500 text-white py-3 rounded-xl font-bold text-xs uppercase tracking-widest shadow-lg shadow-indigo-600/10"
                >
                  Save Changes
                </.button>
              </div>
            </.form>
          </.dark_card>
        </div>
      <% end %>

      <%= if @active_tab == :security do %>
        <div class="animate-in fade-in slide-in-from-bottom-2 duration-500 space-y-6">
          <div class="max-w-4xl">
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div class="lg:col-span-1">
                <h3 class="text-xs font-bold text-slate-400 uppercase tracking-[0.2em] mb-4">
                  Security Overview
                </h3>
                <p class="text-xs text-slate-500 mb-6 leading-relaxed">
                  Monitor and manage your active account sessions across all devices. If you suspect any unauthorized access, revoke the session immediately.
                </p>
                <div class="p-4 rounded-xl bg-indigo-500/5 border border-indigo-500/10">
                  <div class="flex items-center gap-3 mb-2">
                    <span class="hero-shield-check w-5 h-5 text-indigo-400"></span>
                    <span class="text-xs font-bold text-white">Advanced Protection</span>
                  </div>
                  <p class="text-[10px] text-slate-400 leading-tight">
                    Biometric step-up is enabled for high-value transactions and security changes.
                  </p>
                </div>
              </div>

              <div class="lg:col-span-2">
                <.dark_card class="p-0 overflow-hidden">
                  <div class="p-6 border-b border-white/5 flex items-center justify-between bg-slate-900/40">
                    <h3 class="text-xs font-bold text-white">Active Sessions</h3>
                    <span class="px-2 py-1 rounded text-[9px] font-black uppercase tracking-widest bg-emerald-500/10 text-emerald-400">
                      {length(@sessions)} Active
                    </span>
                  </div>

                  <div class="divide-y divide-white/5">
                    <%= for session <- @sessions do %>
                      <div class="p-6 flex items-center justify-between group hover:bg-white/[0.01] transition-colors">
                        <div class="flex items-center gap-4">
                          <div class="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-slate-400 group-hover:text-indigo-400 transition-colors">
                            <%= if String.contains?(String.downcase(session.user_agent || ""), ["iphone", "android"]) do %>
                              <span class="hero-device-phone-mobile w-5 h-5"></span>
                            <% else %>
                              <span class="hero-computer-desktop w-5 h-5"></span>
                            <% end %>
                          </div>
                          <div>
                            <div class="flex items-center gap-2">
                              <p class="text-xs font-bold text-white">
                                {parse_user_agent(session.user_agent)}
                              </p>
                              <%= if session.id == @current_session_id do %>
                                <div class="flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20">
                                  <span class="relative flex h-1.5 w-1.5">
                                    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
                                    </span>
                                    <span class="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500">
                                    </span>
                                  </span>
                                  <span class="text-[8px] font-black uppercase tracking-widest text-emerald-400">
                                    Active Now
                                  </span>
                                </div>
                              <% end %>
                            </div>
                            <p class="text-[10px] text-slate-500 mt-1 uppercase tracking-wider font-medium">
                              {session.ip_address || "Unknown IP"} • Last active {Calendar.strftime(
                                session.last_active_at,
                                "%b %d, %H:%M"
                              )}
                            </p>
                          </div>
                        </div>

                        <%= if session.id != @current_session_id do %>
                          <button
                            phx-click="revoke_session"
                            phx-value-id={session.id}
                            data-confirm="Are you sure you want to revoke this session?"
                            class="opacity-0 group-hover:opacity-100 transition-opacity p-2 text-rose-500 hover:bg-rose-500/10 rounded-lg"
                          >
                            <span class="hero-no-symbol w-5 h-5"></span>
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </.dark_card>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </.page_container>
    """
  end

  @impl true
  def handle_event("validate_settings", %{"user_settings" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params))}
  end

  @impl true
  def handle_event("save_settings", %{"user_settings" => params}, socket) do
    command = %UpdateSettings{
      org_id: socket.assigns.current_user.org_id,
      user_id: socket.assigns.current_user.id,
      locale: params["locale"],
      timezone: params["timezone"],
      notifications_enabled: params["notifications_enabled"] == "true",
      updated_at: DateTime.utc_now()
    }

    case App.dispatch(command) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings updated successfully")
         |> assign(:settings, command)
         |> assign(:form, to_form(params))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update settings: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("revoke_session", %{"id" => session_id}, socket) do
    command = %ExpireSession{
      org_id: socket.assigns.current_user.org_id,
      user_id: socket.assigns.current_user.id,
      session_id: session_id,
      expired_at: DateTime.utc_now()
    }

    case App.dispatch(command) do
      :ok ->
        sessions = Enum.reject(socket.assigns.sessions, &(&1.id == session_id))

        {:noreply,
         socket
         |> put_flash(:info, "Session revoked")
         |> assign(:sessions, sessions)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke session: #{inspect(reason)}")}
    end
  end

  defp parse_user_agent(nil), do: "Unknown Device"

  defp parse_user_agent(ua) do
    cond do
      String.contains?(ua, "Chrome") -> "Google Chrome"
      String.contains?(ua, "Firefox") -> "Mozilla Firefox"
      String.contains?(ua, "Safari") -> "Apple Safari"
      String.contains?(ua, "Postman") -> "Postman API Client"
      true -> "Web Browser"
    end
  end
end
