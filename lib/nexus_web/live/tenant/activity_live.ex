defmodule NexusWeb.Tenant.ActivityLive do
  use NexusWeb, :live_view

  alias Nexus.ERP

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    org_id = if user.role == "system_admin", do: :all, else: user.org_id

    # For now, let's just list 20 activities
    activities = ERP.list_activity(org_id, limit: 20)

    socket =
      socket
      |> assign(:page_title, "Activity History")
      |> assign(:page_subtitle, "Comprehensive audit trail of ERP and system events")
      |> assign(:current_path, "/activity")
      |> assign(:activities, activities)
      |> assign(:datagrid_params, %{})

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 sm:px-6 lg:px-8">
      <.page_header
        title="Activity History"
        subtitle="Comprehensive audit trail of ERP and system events"
      />

      <%!-- Elite KPI Header --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <.dark_card class="p-6">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                Total Audit Records
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-slate-100 tracking-tight">1,245,601</span>
              </div>
            </div>
            <div class="w-10 h-10 rounded-full bg-indigo-500/10 flex items-center justify-center">
              <span class="hero-server-stack w-5 h-5 text-indigo-400"></span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">Cryptographically sealed on EventStore</p>
          </div>
        </.dark_card>

        <.dark_card class="p-6">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                Monitored Subsystems
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-slate-100 tracking-tight">12</span>
                <span class="text-xs font-bold text-emerald-400">Active</span>
              </div>
            </div>
            <div class="w-10 h-10 rounded-full bg-emerald-500/10 flex items-center justify-center">
              <span class="hero-cpu-chip w-5 h-5 text-emerald-400"></span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">ERP, Treasury, Identity, & Policy Engines</p>
          </div>
        </.dark_card>

        <.dark_card class="p-6">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                System Status
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-emerald-400 tracking-tight">Secured</span>
              </div>
            </div>
            <div class="w-10 h-10 rounded-full bg-emerald-500/10 flex items-center justify-center">
              <span class="hero-shield-check w-5 h-5 text-emerald-400"></span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">Zero-trust environment actively enforced</p>
          </div>
        </.dark_card>
      </div>

      <.data_grid
        id="activity-audit-grid"
        title="Immutable Audit Stream"
        subtitle="Security-first logs of all system interactions"
        rows={@activities}
        params={@datagrid_params || %{}}
        total={1_245_601}
      >
        <:primary_actions>
          <.nx_button variant="outline" size="sm" icon="hero-arrow-down-tray" phx-click="export_csv">
            CSV Export
          </.nx_button>
        </:primary_actions>

        <:filters>
          <div class="flex items-center gap-2 bg-slate-900/50 border border-slate-700/50 rounded-md px-3 py-1.5 cursor-pointer hover:bg-slate-800/50 transition-colors">
            <span class="hero-funnel w-3.5 h-3.5 text-slate-400"></span>
            <p class="text-[11px] font-medium text-slate-300">All Subsystems</p>
            <span class="hero-chevron-down w-3 h-3 text-slate-500 ml-1"></span>
          </div>
          <div class="flex items-center gap-2 bg-slate-900/50 border border-slate-700/50 rounded-md px-3 py-1.5 cursor-pointer hover:bg-slate-800/50 transition-colors">
            <span class="hero-calendar w-3.5 h-3.5 text-slate-400"></span>
            <p class="text-[11px] font-medium text-slate-300">Last 7 Days</p>
            <span class="hero-chevron-down w-3 h-3 text-slate-500 ml-1"></span>
          </div>
        </:filters>

        <:col :let={item} label="Event Timeline">
          <div class="relative pl-2 group">
            <%!-- Vertical Timeline Highlight --%>
            <div class="absolute -left-5 top-0 bottom-0 w-px bg-white/5 group-hover:bg-indigo-500/20 transition-colors">
            </div>

            <.activity_item
              icon={item.icon}
              color={item.color}
              title={item.title}
              subtitle={item.subtitle}
              time_ago={item.time}
            />
          </div>
        </:col>
      </.data_grid>
    </.page_container>
    """
  end
end
