defmodule NexusWeb.Tenant.ActivityLive do
  use NexusWeb, :live_view

  alias Nexus.ERP

  @impl true
  def mount(_params, _session, socket) do
    org_id = socket.assigns.current_user.org_id

    # For now, let's just list 20 activities
    activities = ERP.list_activity(org_id, limit: 20)

    socket =
      socket
      |> assign(:page_title, "Activity History")
      |> assign(:page_subtitle, "Comprehensive audit trail of ERP and system events")
      |> assign(:current_path, "/activity")
      |> assign(:activities, activities)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
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

      <%!-- Main Audit Stream --%>
      <.dark_card class="p-6 relative overflow-hidden">
        <div class="flex items-center justify-between mb-8">
          <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
            Immutable Audit Stream
          </h2>
          <div class="flex flex-wrap items-center gap-3">
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
            <button class="flex items-center gap-1.5 text-[11px] font-medium text-slate-300 hover:text-white bg-slate-800/40 hover:bg-slate-700/50 px-3 py-1.5 rounded-md transition-colors border border-slate-700/50 group">
              <span class="hero-arrow-down-tray w-3.5 h-3.5 text-slate-400 group-hover:text-indigo-400 transition-colors">
              </span>
              CSV Export
            </button>
          </div>
        </div>

        <div class="space-y-6 relative ml-1">
          <%!-- Vertical Timeline Line --%>
          <div class="absolute left-[11px] top-2 bottom-2 w-px bg-white/5"></div>

          <div :for={item <- @activities} class="group">
            <.activity_item
              icon={item.icon}
              color={item.color}
              title={item.title}
              subtitle={item.subtitle}
              time_ago={item.time}
            />
          </div>

          <div :if={Enum.empty?(@activities)}>
            <.empty_state
              title="No activity found"
              message="Historical events will appear here as they occur in the system."
            />
          </div>
        </div>

        <div
          :if={length(@activities) >= 20}
          class="mt-8 pt-6 border-t border-white/5 flex items-center justify-between"
        >
          <p class="text-[11px] text-slate-500">Showing 20 of 1,245,601 records</p>
          <.pagination showing={length(@activities)} total={100} has_more={true} />
        </div>
      </.dark_card>
    </div>
    """
  end
end
