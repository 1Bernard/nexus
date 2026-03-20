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

  def sod_matrix(assigns) do
    # Define the base RBAC matrix for the UI
    roles = [
      %{name: "Admin", permissions: ["Authorize", "Policy", "Audit"]},
      %{name: "Trader", permissions: ["Initiate"]},
      %{name: "Auditor", permissions: ["Audit"]},
      %{name: "Viewer", permissions: []}
    ]

    permissions = ["Initiate", "Authorize", "Policy", "Audit"]

    assigns = assign(assigns, roles: roles, permissions: permissions)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left border-collapse">
        <thead>
          <tr class="border-b border-white/5">
            <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
              Role
            </th>
            <%= for perm <- @permissions do %>
              <th class="py-4 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-center">
                {perm}
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="divide-y divide-white/5">
          <%= for role <- @roles do %>
            <tr class="group hover:bg-white/[0.02] transition-colors">
              <td class="py-4 px-2">
                <span class="text-xs font-bold text-slate-300">{role.name}</span>
              </td>
              <%= for perm <- @permissions do %>
                <td class="py-4 px-2 text-center">
                  <div class={
                    [
                      "mx-auto w-3 h-3 rounded-sm border",
                      if(perm in role.permissions,
                        do: "bg-emerald-500/20 border-emerald-500/40",
                        else: "bg-slate-800/20 border-slate-800/50"
                      ),
                      # Highlight toxic combination if user has both Initiate and Authorize/Policy
                      role.name == "Admin" && perm == "Initiate" &&
                        "bg-rose-500/20 border-rose-500/40 shadow-[0_0_8px_rgba(244,63,94,0.3)] animate-pulse"
                    ]
                  }>
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
end
