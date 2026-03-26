defmodule NexusWeb.Reporting.ComplianceComponents do
  @moduledoc """
  UI components for the Compliance & Audit Hub.
  Features specialized gauges and lineage visualization.
  """
  use Phoenix.Component

  @doc """
  Displays a high-density compliance metric gauge.
  """
  attr :label, :string, required: true
  # 0-100
  attr :score, :integer, required: true
  attr :status, :string, default: "Healthy"
  attr :icon, :string, default: "hero-shield-check"
  attr :trend, :any, default: nil # e.g. 0.05 for +5%

  def compliance_gauge(assigns) do
    ~H"""
    <div class="relative flex flex-col items-center justify-center p-6 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl group transition-all hover:border-[var(--nx-border-hover)] h-full min-h-[180px]">
      <div class="relative w-24 h-24">
        <%!-- Radial Track --%>
        <svg class="w-full h-full -rotate-90" viewBox="0 0 100 100">
          <circle
            cx="50"
            cy="50"
            r="44"
            fill="none"
            stroke="currentColor"
            stroke-width="8"
            class="text-slate-700/40"
          />
          <circle
            cx="50"
            cy="50"
            r="44"
            fill="none"
            stroke="currentColor"
            stroke-width="8"
            stroke-dasharray="276"
            stroke-dashoffset={276 - 276 * @score / 100}
            stroke-linecap="round"
            class={[
              "transition-all duration-1000",
              @score >= 95 && "text-emerald-500",
              @score < 95 && @score >= 80 && "text-amber-500",
              @score < 80 && "text-rose-500"
            ]}
          />
        </svg>
        <div class="absolute inset-0 flex flex-col items-center justify-center">
          <span class="text-xl font-black text-slate-100 tracking-tighter">{@score}%</span>
          <%= if @trend do %>
            <div class={[
              "flex items-center gap-0.5 mt-0.5",
              Decimal.gt?(@trend, 0) && "text-emerald-400",
              Decimal.lt?(@trend, 0) && "text-rose-400",
              Decimal.eq?(@trend, 0) && "text-slate-500"
            ]}>
              <span class={[
                "text-[8px] font-bold",
                Decimal.gt?(@trend, 0) && "hero-arrow-trending-up w-2.5 h-2.5",
                Decimal.lt?(@trend, 0) && "hero-arrow-trending-down w-2.5 h-2.5"
              ]}></span>
              <span class="text-[8px] font-bold">{abs(Decimal.to_float(@trend) * 100)}%</span>
            </div>
          <% end %>
        </div>
      </div>
      <div class="mt-4 text-center">
        <h4 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
          {@label}
        </h4>
        <div class="flex items-center justify-center gap-1.5">
          <span class={[
            "w-1.5 h-1.5 rounded-full",
            @score >= 95 && "bg-emerald-400 animate-pulse",
            @score < 95 && @score >= 80 && "bg-amber-400",
            @score < 80 && "bg-rose-400"
          ]}>
          </span>
          <p class="text-[11px] font-medium text-slate-300">{@status}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Displays the Segregation of Duties (SoD) Matrix.
  """
  attr :conflicts, :list, default: []
  attr :roles, :list, required: true # e.g. ["admin", "trader", "approver", "viewer"]

  def sod_matrix(assigns) do
    # Map roles to their theoretical permissions for highlighting
    role_map = %{
      "admin" => ["Initiate", "Authorize", "Policy", "Audit"],
      "trader" => ["Initiate"],
      "approver" => ["Authorize"],
      "viewer" => ["Audit"],
      "system_admin" => ["Authorize", "Policy", "Audit"]
    }

    permissions = ["Initiate", "Authorize", "Policy", "Audit"]

    assigns = assign(assigns, role_map: role_map, permissions: permissions)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="border-b border-[var(--nx-border)]">
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Role Profile
            </th>
            <%= for perm <- @permissions do %>
              <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center">
                {perm}
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="divide-y divide-[var(--nx-border)]">
          <%= for role <- @roles do %>
            <tr class="group hover:bg-white/[0.02] transition-colors">
              <td class="py-4 px-2">
                <span class="text-xs font-bold text-slate-300 uppercase leading-none">{role}</span>
              </td>
              <%= for perm <- @permissions do %>
                <td class="py-4 px-2 text-center">
                  <% role_perms = Map.get(@role_map, role, []) %>
                  <div class={
                    [
                      "mx-auto w-3.5 h-3.5 rounded-sm border transition-all duration-500",
                      if(perm in role_perms,
                        do: "bg-emerald-500/20 border-emerald-500/40 shadow-[0_0_10px_rgba(16,185,129,0.1)]",
                        else: "bg-slate-800/10 border-slate-800/50"
                      ),
                      # Toxic Combinations detection
                      (role == "admin" || (role == "system_admin" && perm == "Authorize")) &&
                        "border-amber-500/30 group-hover:border-amber-500/50"
                    ]
                  }>
                    <%= if perm in role_perms do %>
                      <div class="w-1.5 h-1.5 bg-emerald-400 rounded-full mx-auto mt-0.5"></div>
                    <% end %>
                  </div>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Form for generating audit samples.
  """
  attr :method, :string, default: "random"
  attr :size, :integer, default: 10

  def sampling_form(assigns) do
    ~H"""
    <form phx-submit="generate_sample" class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end bg-black/20 p-6 rounded-2xl border border-white/5">
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">Method</label>
        <select name="method" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-200 outline-none focus:ring-1 focus:ring-indigo-500">
          <option value="random">Random Selection</option>
          <option value="risk_based">Risk-Based Prioritization</option>
          <option value="high_value">High-Value Concentration</option>
        </select>
      </div>
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">Sample Size</label>
        <input type="number" name="size" value={@size} class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-200 outline-none focus:ring-1 focus:ring-indigo-500" />
      </div>
      <div>
        <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">Threshold (USD)</label>
        <input type="number" name="threshold" value="100000" class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-200 outline-none focus:ring-1 focus:ring-indigo-500" />
      </div>
      <button type="submit" class="h-9 px-6 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold uppercase rounded-lg transition-colors">
        Generate Sample
      </button>
    </form>
    """
  end

  @doc """
  Displays the generated audit sample table.
  """
  attr :samples, :list, required: true

  def sample_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left border-collapse">
        <thead class="border-b border-white/10">
          <tr>
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Event</th>
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Timestamp</th>
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest">Actor</th>
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">Attestation</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-white/5">
          <%= for sample <- @samples do %>
            <tr class="group hover:bg-white/[0.02] transition-colors">
              <td class="py-4 px-2">
                <div class="flex flex-col">
                  <span class="text-xs font-bold text-slate-200 uppercase tracking-tight">{sample.event_type}</span>
                  <span class="text-[9px] text-slate-500 font-mono mt-0.5">{String.slice(sample.id, 0, 8)}...</span>
                </div>
              </td>
              <td class="py-4 px-2">
                <span class="text-[11px] text-slate-400 font-mono">{Calendar.strftime(sample.recorded_at, "%Y-%m-%d %H:%M:%S")}</span>
              </td>
              <td class="py-4 px-2">
                <span class="text-[11px] text-slate-400">{sample.actor_email}</span>
              </td>
              <td class="py-4 px-2 text-right">
                <div class="flex items-center justify-end gap-2">
                  <button class="p-1 px-2 rounded bg-slate-800 text-[9px] font-bold text-slate-400 hover:text-emerald-400 border border-white/5 hover:border-emerald-500/30 transition-all uppercase">Verify</button>
                  <button class="p-1 px-2 rounded bg-slate-800 text-[9px] font-bold text-slate-400 hover:text-rose-400 border border-white/5 hover:border-rose-500/30 transition-all uppercase">Flag</button>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
