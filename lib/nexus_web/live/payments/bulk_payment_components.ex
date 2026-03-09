defmodule NexusWeb.Payments.BulkPaymentComponents do
  @moduledoc """
  Reusable components for the Bulk Payment Gateway UI.
  """
  use Phoenix.Component
  import NexusWeb.NexusComponents, only: [badge: 1]

  @doc "Renders a single bulk payment batch row."
  attr :batch, :map, required: true

  def batch_row(assigns) do
    ~H"""
    <div class="flex items-center gap-4 px-5 py-4 rounded-xl bg-white/[0.02] border border-white/[0.05] hover:bg-white/[0.04] transition-colors group">
      <%!-- Batch Icon --%>
      <div class="flex-shrink-0 w-12 h-12 rounded-xl bg-gradient-to-br from-indigo-500/10 to-purple-500/10 ring-1 ring-white/10 flex items-center justify-center shadow-lg">
        <span class="hero-bolt w-6 h-6 text-indigo-400"></span>
      </div>

      <%!-- ID + Date --%>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <p class="text-sm text-white font-medium truncate">Batch {String.slice(@batch.id, 0, 8)}</p>
          <.badge
            variant={if(@batch.status == "completed", do: "success", else: "warning")}
            label={@batch.status}
          />
        </div>
        <p class="text-[10px] text-slate-500 mt-1 font-mono uppercase tracking-wider">
          Initiated {format_datetime(@batch.created_at)}
        </p>
      </div>

      <%!-- Stats --%>
      <div class="text-right flex-shrink-0">
        <p class="text-sm font-semibold text-white tabular-nums">{@batch.total_amount} EUR</p>
        <p class="text-[10px] text-slate-500 uppercase tracking-wider">{@batch.total_items} items</p>
      </div>

      <%!-- Progress bar --%>
      <div class="hidden md:flex flex-col gap-1.5 w-40 flex-shrink-0">
        <div class="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
          <span class="text-slate-500 font-mono">{@batch.processed_items}/{@batch.total_items}</span>
          <span class={[
            "font-mono",
            if(@batch.status == "completed", do: "text-emerald-400", else: "text-indigo-400")
          ]}>
            {calculate_progress(@batch)}% PROCESSED
          </span>
        </div>
        <div class="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
          <div
            class={[
              "h-full rounded-full transition-all duration-1000",
              if(@batch.status == "completed", do: "bg-emerald-500", else: "bg-indigo-500")
            ]}
            style={"width: #{calculate_progress(@batch)}%"}
          />
        </div>
      </div>
    </div>
    """
  end

  @doc "Renders the empty state for the batches list."
  def batches_empty(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-24 gap-4 text-center">
      <div class="w-16 h-16 rounded-2xl bg-white/[0.03] ring-1 ring-white/10 flex items-center justify-center">
        <span class="hero-credit-card w-8 h-8 text-slate-600"></span>
      </div>
      <p class="text-slate-400 text-sm font-medium">No bulk payments found</p>
      <p class="text-slate-600 text-xs">
        Upload a CSV file above to initiate your first payment batch
      </p>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")
  defp format_datetime(_), do: "—"

  defp calculate_progress(%{total_items: 0}), do: 0

  defp calculate_progress(%{total_items: total, processed_items: processed}) do
    round(processed / total * 100)
  end
end
