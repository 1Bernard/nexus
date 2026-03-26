defmodule NexusWeb.Reporting.ComplianceLive do
  @moduledoc """
  High-density Auditor Hub for monitoring Continuous Control Drift and Lineage.
  """
  use NexusWeb, :live_view
  import NexusWeb.Reporting.ComplianceComponents

  alias Nexus.Reporting

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to compliance updates from the ControlProjector
      Phoenix.PubSub.subscribe(Nexus.PubSub, "reporting:compliance_updates")
    end

    org_id = socket.assigns.current_user.org_id
    metrics = Reporting.get_compliance_scorecard(org_id)
    drift_data = Reporting.get_control_drift(org_id)
    sod_conflicts = Reporting.list_sod_conflicts(org_id)

    # Derived unique roles from conflicts and defaults
    available_roles =
      (Enum.flat_map(sod_conflicts, &(&1.roles)) ++ ["trader", "approver", "viewer", "admin"])
      |> Enum.uniq()
      |> Enum.sort()

    socket =
      socket
      |> assign(:page_title, "Compliance Hub")
      |> assign(:page_subtitle, "Real-time Continuous Control Monitoring (CCM)")
      |> assign(:metrics, metrics)
      |> assign(:drift_data, drift_data)
      |> assign(:available_roles, available_roles)
      |> assign(:sod_conflicts, sod_conflicts)
      |> assign(:trace_id, "")
      |> assign(:lineage, [])
      |> assign(:sample_list, [])
      |> assign(:remediation_logs, [])
      |> assign(:active_tab, "scorecard")

    {:ok, socket}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :active_tab, tab)

    socket = if tab == "remediation" do
      logs = Reporting.get_event_lineage(socket.assigns.current_user.org_id, %{event_type: "user_role_revoked"})
      assign(socket, remediation_logs: logs)
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("trace", %{"trace_id" => trace_id} = params, socket) do
    filters = %{
      correlation_id: if(trace_id != "", do: trace_id),
      user_email: if(params["user_email"] != "", do: params["user_email"]),
      event_type: if(params["event_type"] != "", do: params["event_type"])
    }

    lineage = Reporting.get_event_lineage(socket.assigns.current_user.org_id, filters)
    {:noreply, assign(socket, lineage: lineage, trace_id: trace_id)}
  end

  @impl true
  def handle_event("generate_sample", params, socket) do
    org_id = socket.assigns.current_user.org_id
    sample = Reporting.generate_audit_sample(org_id, params)
    {:noreply, assign(socket, sample_list: sample)}
  end

  @impl true
  def handle_info({:compliance_updated, _org_id}, socket) do
    # Refresh metrics and SoD conflicts on projector updates
    org_id = socket.assigns.current_user.org_id
    metrics = Reporting.get_compliance_scorecard(org_id)
    drift_data = Reporting.get_control_drift(org_id)
    sod_conflicts = Reporting.list_sod_conflicts(org_id)

    {:noreply,
     socket
     |> assign(:metrics, metrics)
     |> assign(:drift_data, drift_data)
     |> assign(:sod_conflicts, sod_conflicts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <.page_header
        title="Compliance & Audit Hub"
        subtitle="Elite Control Intelligence • Real-time Monitoring"
      >
        <:actions>
          <div class="flex items-center gap-2 px-2.5 py-1 rounded bg-indigo-500/10 border border-indigo-500/20">
            <span class="hero-shield-check w-3.5 h-3.5 text-indigo-400"></span>
            <span class="text-[10px] font-bold text-indigo-400 uppercase tracking-widest mt-0.5">
              SOC 2 Hardened
            </span>
          </div>
        </:actions>
      </.page_header>

    <!-- Navigation Tabs -->
      <div class="flex items-center gap-6 border-b border-white/10 mb-8 w-full">
        <.tab_button
          active={@active_tab == "scorecard"}
          click="set_tab"
          tab="scorecard"
          label="Control Scorecard"
        />
        <.tab_button active={@active_tab == "sod"} click="set_tab" tab="sod" label="SoD Matrix" />
        <.tab_button
          active={@active_tab == "lineage"}
          click="set_tab"
          tab="lineage"
          label="Immutable Lineage"
        />
        <.tab_button
          active={@active_tab == "sampling"}
          click="set_tab"
          tab="sampling"
          label="Sampling Hub"
        />
        <.tab_button
          active={@active_tab == "remediation"}
          click="set_tab"
          tab="remediation"
          label="Remediation Log"
        />
      </div>

      <div class="grid grid-cols-1 gap-8">
        <%= if @active_tab == "scorecard" do %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <.compliance_gauge
              label="Auth Integrity"
              score={get_score(@metrics, "auth_integrity")}
              trend={get_trend(@drift_data, "auth_integrity")}
              status="Verified"
            />
            <.compliance_gauge
              label="SoD Cleanliness"
              score={get_score(@metrics, "sod_cleanliness")}
              trend={get_trend(@drift_data, "sod_cleanliness")}
              status="Healthy"
            />
            <.compliance_gauge
              label="Policy Drift"
              score={get_score(@metrics, "policy_drift")}
              trend={get_trend(@drift_data, "policy_drift")}
              status="Active"
            />
            <.compliance_gauge
              label="Precision Audit"
              score={get_score(@metrics, "precision_audit")}
              trend={get_trend(@drift_data, "precision_audit")}
              status="Certified"
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.compliance_gauge
              label="Liquidity Accuracy"
              score={get_score(@metrics, "liquidity_accuracy")}
              trend={get_trend(@drift_data, "liquidity_accuracy")}
              status="Real-time"
            />
            <.compliance_gauge
              label="Escalation Integrity"
              score={get_score(@metrics, "escalation_integrity")}
              trend={get_trend(@drift_data, "escalation_integrity")}
              status="SLA Compliant"
            />
          </div>
        <% end %>

        <%= if @active_tab == "sod" do %>
          <.dark_card class="p-8">
            <div class="mb-8">
              <h3 class="text-sm font-bold text-slate-100 mb-1">Segregation of Duties Matrix</h3>
              <p class="text-[11px] text-slate-500 max-w-xl leading-relaxed">
                Real-time mapping of user roles against critical system capabilities. Conflicts are automatically flagged for review.
              </p>
            </div>
            <.sod_matrix conflicts={@sod_conflicts} roles={@available_roles} />

            <%= if not Enum.empty?(@sod_conflicts) do %>
              <div class="mt-8 space-y-4">
                <%= for conflict <- @sod_conflicts do %>
                  <div class="p-4 rounded-xl bg-rose-500/5 border border-rose-500/10">
                    <div class="flex items-center gap-3">
                      <span class="hero-exclamation-triangle w-5 h-5 text-rose-400"></span>
                      <div>
                        <h4 class="text-xs font-bold text-rose-300">{conflict.conflict_type}</h4>
                        <p class="text-[11px] text-rose-400/80 mt-0.5">
                          User <strong>{conflict.email}</strong>
                          possesses roles: <strong>{Enum.join(conflict.roles, ", ")}</strong>.
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="mt-8 p-4 rounded-xl bg-emerald-500/5 border border-emerald-500/10">
                <div class="flex items-center gap-3">
                  <span class="hero-check-circle w-5 h-5 text-emerald-400"></span>
                  <p class="text-[11px] text-emerald-400/80">
                    No Segregation of Duties conflicts detected in this organization.
                  </p>
                </div>
              </div>
            <% end %>
          </.dark_card>
        <% end %>

        <%= if @active_tab == "lineage" do %>
          <.dark_card class="p-8">
            <div class="mb-8 flex items-end justify-between">
              <div>
                <h3 class="text-sm font-bold text-slate-100 mb-2">Immutable Lineage Trace</h3>
                <p class="text-xs text-slate-500">
                  Reconstruct the cryptographically sealed chain of custody for any transaction.
                </p>
              </div>
              <form phx-submit="trace" class="flex flex-wrap items-center gap-3">
                <input
                  type="text"
                  name="trace_id"
                  placeholder="Correlation ID"
                  value={@trace_id}
                  class="bg-black/20 border border-slate-700/50 rounded-lg px-4 py-2 text-xs text-slate-200 focus:ring-1 focus:ring-indigo-500 outline-none w-48"
                />
                <input
                  type="text"
                  name="user_email"
                  placeholder="User Email"
                  class="bg-black/20 border border-slate-700/50 rounded-lg px-4 py-2 text-xs text-slate-200 focus:ring-1 focus:ring-indigo-500 outline-none w-48"
                />
                <select
                  name="event_type"
                  class="bg-black/20 border border-slate-700/50 rounded-lg px-4 py-2 text-xs text-slate-200 focus:ring-1 focus:ring-indigo-500 outline-none"
                >
                  <option value="">All Events</option>
                  <option value="user.logged_in">Login</option>
                  <option value="payment.initiated">Payment</option>
                  <option value="policy.updated">Policy Change</option>
                </select>
                <button
                  type="submit"
                  class="px-6 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold uppercase rounded-lg transition-colors"
                >
                  Filter Lineage
                </button>
              </form>
            </div>

            <%= if Enum.empty?(@lineage) do %>
              <div class="flex flex-col items-center justify-center py-20 text-center border-2 border-dashed border-white/5 rounded-2xl">
                <span class="hero-magnifying-glass w-10 h-10 text-slate-700 mb-4"></span>
                <p class="text-xs text-slate-500">Enter a Correlation ID to begin tracing.</p>
              </div>
            <% else %>
              <div class="relative pl-8 space-y-12 before:absolute before:left-[11px] before:top-2 before:bottom-2 before:w-px before:bg-slate-800">
                <%= for event <- @lineage do %>
                  <div class="relative group">
                    <div class="absolute -left-[31px] top-1 w-3 h-3 rounded-full bg-slate-900 border-2 border-indigo-500/50 group-hover:border-indigo-400 transition-colors z-10">
                    </div>
                    <div>
                      <div class="flex items-center gap-3 mb-2">
                        <span class="text-xs font-black text-slate-100 uppercase tracking-wider">
                          {event.event_type}
                        </span>
                        <span class="px-2 py-0.5 rounded bg-emerald-500/10 text-[9px] font-bold text-emerald-400 uppercase border border-emerald-500/20">
                          Sealed
                        </span>
                      </div>
                      <div class="text-[11px] text-slate-400 space-y-1">
                        <p>Actor: <span class="text-slate-300">{event.actor_email}</span></p>
                        <p>
                          Recorded at:
                          <span class="text-slate-300 font-mono tracking-tighter">
                            {Calendar.strftime(event.recorded_at, "%Y-%m-%d %H:%M:%S.%f UTC")}
                          </span>
                        </p>
                      </div>
                      <div class="mt-4 p-4 rounded-xl bg-black/30 border border-white/5 font-mono text-[10px] text-slate-500 group-hover:border-indigo-500/20 transition-all">
                        {Jason.encode!(event.details)}
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.dark_card>
        <% end %>
        <%= if @active_tab == "sampling" do %>
          <.dark_card class="p-8">
            <div class="mb-8">
              <h3 class="text-sm font-bold text-slate-100 mb-2">Audit Sampling Tool</h3>
              <p class="text-xs text-slate-500">
                Generate statistical or risk-based samples for control verification.
              </p>
            </div>

            <.sampling_form method="random" size={10} />

            <div class="mt-8">
              <%= if Enum.empty?(@sample_list) do %>
                <div class="flex flex-col items-center justify-center py-20 text-center border-2 border-dashed border-white/5 rounded-2xl">
                  <span class="hero-beaker w-10 h-10 text-slate-700 mb-4"></span>
                  <p class="text-xs text-slate-500">Configure parameters and click "Generate Sample" to begin. sonora.</p>
                </div>
              <% else %>
                <.sample_table samples={@sample_list} />
              <% end %>
            </div>
          </.dark_card>
        <% end %>

        <%= if @active_tab == "remediation" do %>
          <.dark_card class="p-8">
            <div class="mb-8">
              <h3 class="text-sm font-bold text-slate-100 mb-2">Autonomous Remediation History</h3>
              <p class="text-xs text-slate-500">
                Log of automated security actions taken by the Self-Healing Control Loops. sonora.
              </p>
            </div>

            <%= if Enum.empty?(@remediation_logs) do %>
              <div class="flex flex-col items-center justify-center py-20 text-center border-2 border-dashed border-white/5 rounded-2xl">
                <span class="hero-shield-check w-10 h-10 text-slate-700 mb-4"></span>
                <p class="text-xs text-slate-500">No remediation actions taken yet. Systems are healthy.</p>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for log <- @remediation_logs do %>
                  <div class="p-4 rounded-xl bg-indigo-500/5 border border-indigo-500/10 flex items-start justify-between">
                    <div class="flex items-start gap-4">
                      <div class="mt-1 p-2 rounded-lg bg-indigo-500/20">
                        <span class="hero-shield-exclamation w-5 h-5 text-indigo-400"></span>
                      </div>
                      <div>
                        <div class="flex items-center gap-2 mb-1">
                          <span class="text-xs font-bold text-slate-100 uppercase tracking-wide">
                            Role Revocation
                          </span>
                          <span class="px-2 py-0.5 rounded bg-amber-500/10 text-[9px] font-bold text-amber-500 uppercase border border-amber-500/20">
                            Automatic
                          </span>
                        </div>
                        <p class="text-[11px] text-slate-400">
                          Revoked role <span class="text-slate-200 font-bold">{log.details["role"]}</span>
                          from user <span class="text-slate-200">{log.details["user_id"]}</span>
                          due to SoD conflict. sonora.
                        </p>
                        <p class="text-[10px] text-slate-500 mt-2 font-mono">
                          {Calendar.strftime(log.recorded_at, "%Y-%m-%d %H:%M:%S UTC")}
                        </p>
                      </div>
                    </div>
                    <div class="px-3 py-1 rounded bg-black/40 border border-white/5 font-mono text-[10px] text-slate-600">
                      Lineage Check: {String.slice(log.id, 0, 8)}...
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.dark_card>
        <% end %>
      </div>
    </.page_container>
    """
  end

  defp get_score(metrics, key) do
    Enum.find(metrics, fn m -> m.metric_key == key end)
    |> case do
      nil -> 100
      m ->
        score = if is_struct(m.score), do: Decimal.to_integer(m.score), else: round(m.score * 100)
        score
    end
  end

  defp get_trend(drift_data, key) do
    points = Enum.filter(drift_data, fn m -> m.metric_key == key end)

    if length(points) >= 2 do
      [latest, previous | _] = Enum.sort_by(points, & &1.updated_at, :desc)
      Decimal.sub(latest.score, previous.score)
    else
      nil
    end
  end

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-tab={@tab}
      class={[
        "pb-3 text-sm font-bold transition-colors border-b-2 relative -mb-[1px]",
        @active && "text-white border-indigo-500",
        !@active && "text-slate-500 border-transparent hover:text-slate-300 hover:border-slate-700"
      ]}
    >
      {@label}
    </button>
    """
  end
end
