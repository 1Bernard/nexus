defmodule NexusWeb.Admin.PolicyComponents do
  use NexusWeb, :html

  attr :modes, :map, required: true

  def risk_gauge(assigns) do
    # Calculate percentages for visualization
    # We use log scales or relative proportions to make it look "Elite"
    strict = parse_val(assigns.modes["strict"])
    standard = parse_val(assigns.modes["standard"])
    relaxed = parse_val(assigns.modes["relaxed"])

    max_val = max(relaxed, 1)
    assigns = assign(assigns, :strict_p, (strict / max_val * 100) |> min(100))
    assigns = assign(assigns, :standard_p, (standard / max_val * 100) |> min(100))

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between px-1">
        <span class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Risk Exposure Bands</span>
        <span class="text-[10px] font-bold text-indigo-400 uppercase tracking-widest">Total Ops Cap: €{format_large_val(@modes["relaxed"])}</span>
      </div>

      <div class="h-4 w-full bg-slate-900/80 rounded-full overflow-hidden border border-white/5 flex p-0.5">
        <div
          class="h-full bg-rose-500/80 rounded-full transition-all duration-700 ease-out shadow-[0_0_15px_rgba(244,63,94,0.3)]"
          style={"width: #{@strict_p}%"}
        ></div>
        <div
          class="h-full bg-amber-500/60 rounded-full -ml-1 transition-all duration-700 delay-100 ease-out"
          style={"width: #{max(0, @standard_p - @strict_p)}%"}
        ></div>
        <div
          class="h-full bg-indigo-500/40 rounded-full -ml-1 transition-all duration-700 delay-200 ease-out"
          style={"width: #{max(0, 100 - @standard_p)}%"}
        ></div>
      </div>

      <div class="grid grid-cols-3 gap-2 px-1">
        <div class="flex items-center gap-1.5">
          <div class="w-1.5 h-1.5 rounded-full bg-rose-500"></div>
          <span class="text-[9px] font-medium text-slate-400">Strict Protection</span>
        </div>
        <div class="flex items-center gap-1.5 justify-center">
          <div class="w-1.5 h-1.5 rounded-full bg-amber-500"></div>
          <span class="text-[9px] font-medium text-slate-400">Standard Guard</span>
        </div>
        <div class="flex items-center gap-1.5 justify-end">
          <div class="w-1.5 h-1.5 rounded-full bg-indigo-500"></div>
          <span class="text-[9px] font-medium text-slate-400">Relaxed Ops</span>
        </div>
      </div>
    </div>
    """
  end

  attr :audits, :list, required: true

  def audit_panel(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <h3 class="text-xs font-bold text-slate-400 uppercase tracking-[0.2em] mb-4 flex items-center gap-2">
        <span class="hero-clock w-3.5 h-3.5 text-indigo-400"></span> Governance History
      </h3>

      <div class="flex-1 space-y-4 overflow-y-auto pr-2 scrollbar-hide">
        <%= for log <- @audits do %>
          <div class="relative pl-4 border-l border-white/5 group">
            <div class="absolute -left-[3px] top-1 w-1.5 h-1.5 rounded-full bg-slate-700 group-hover:bg-indigo-500 transition-colors"></div>
            <div class="flex flex-col gap-1">
              <div class="flex items-center justify-between">
                <span class="text-[10px] font-bold text-slate-200 uppercase tracking-wider">
                  <%= if log.mode == "CONFIG", do: "Policy Configuration", else: "Policy Update" %>
                </span>
                <span class="text-[9px] font-mono text-slate-500">
                  {format_dt(log.changed_at)}
                </span>
              </div>
              <p class="text-[10px] text-slate-400 leading-relaxed">
                <%= if log.mode == "CONFIG" do %>
                  Thresholds updated by {log.actor_email}
                <% else %>
                  Mode changed to <span class="text-indigo-400 font-bold uppercase">{log.mode}</span> by {log.actor_email}
                <% end %>
              </p>
            </div>
          </div>
        <% end %>


        <%= if Enum.empty?(@audits) do %>
          <div class="flex flex-col items-center justify-center py-10 opacity-30">
            <span class="hero-document-magnifying-glass w-10 h-10 mb-2"></span>
            <p class="text-[10px] font-bold uppercase tracking-widest">No audit history found</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp parse_val(nil), do: 0.0

  defp parse_val(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} ->
        num

      :error ->
        case Integer.parse(val) do
          {num, _} -> num / 1.0
          :error -> 0.0
        end
    end
  end

  defp parse_val(val) when is_integer(val), do: val / 1.0
  defp parse_val(val), do: val / 1.0

  defp format_large_val(val) do
    num = parse_val(val)

    cond do
      num >= 1_000_000 -> "#{Float.round(num / 1_000_000, 1)}M"
      num >= 1_000 -> "#{Float.round(num / 1_000, 0) |> round()}K"
      true -> "#{round(num)}"
    end
  end

  defp format_dt(dt) do
    Calendar.strftime(dt, "%b %d, %H:%M")
  end
end
