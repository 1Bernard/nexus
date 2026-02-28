defmodule NexusWeb.ERP.StatementComponents do
  @moduledoc """
  Reusable components for the Document Gateway / Statement upload UI.
  """
  use Phoenix.Component

  @doc "Renders a single statement row in the statements table."
  attr :statement, :map, required: true
  attr :on_expand, :string, default: nil

  def statement_row(assigns) do
    ~H"""
    <div class="flex items-center gap-4 px-5 py-3.5 rounded-xl bg-white/[0.02] border border-white/[0.05] hover:bg-white/[0.04] transition-colors group">
      <%!-- Format badge --%>
      <div class={[
        "flex-shrink-0 w-14 h-8 rounded-lg flex items-center justify-center text-[10px] font-bold tracking-widest uppercase",
        format_badge_class(@statement.format)
      ]}>
        {@statement.format}
      </div>

      <%!-- Filename + meta --%>
      <div class="flex-1 min-w-0">
        <p class="text-sm text-white font-medium truncate">{@statement.filename}</p>
        <p class="text-[10px] text-slate-500 mt-0.5 font-mono">
          Uploaded {format_datetime(@statement.uploaded_at)}
        </p>
      </div>

      <%!-- Line count --%>
      <div class="text-right flex-shrink-0">
        <p class="text-sm font-semibold text-white tabular-nums">{@statement.line_count}</p>
        <p class="text-[10px] text-slate-500 uppercase tracking-wider">lines</p>
      </div>

      <%!-- Status pill --%>
      <div class={[
        "flex-shrink-0 px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
        status_pill_class(@statement.status)
      ]}>
        {@statement.status}
      </div>
    </div>
    """
  end

  @doc "Renders a parsed transaction line row."
  attr :line, :map, required: true

  def statement_line_row(assigns) do
    ~H"""
    <div class="flex items-center gap-4 px-4 py-2.5 text-xs border-b border-white/[0.04] last:border-0">
      <span class="w-24 flex-shrink-0 text-slate-400 font-mono tabular-nums">{@line.date}</span>
      <span class="flex-1 text-slate-300 truncate">{@line.narrative}</span>
      <span class="w-28 text-right flex-shrink-0 font-mono font-semibold tabular-nums text-white">
        {format_amount(@line.amount, @line.currency)}
      </span>
    </div>
    """
  end

  @doc "Renders the empty state for the statements list."
  def statements_empty(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-24 gap-4 text-center">
      <div class="w-16 h-16 rounded-2xl bg-white/[0.03] ring-1 ring-white/10 flex items-center justify-center">
        <span class="hero-document-arrow-up w-8 h-8 text-slate-600"></span>
      </div>
      <p class="text-slate-400 text-sm font-medium">No statements uploaded yet</p>
      <p class="text-slate-600 text-xs">Drag and drop an MT940 or CSV file above to get started</p>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_badge_class("mt940"),
    do: "bg-violet-500/10 text-violet-400 ring-1 ring-violet-500/20"

  defp format_badge_class("csv"), do: "bg-cyan-500/10 text-cyan-400 ring-1 ring-cyan-500/20"
  defp format_badge_class(_), do: "bg-slate-500/10 text-slate-400 ring-1 ring-slate-500/20"

  defp status_pill_class("uploaded"), do: "bg-emerald-500/10 text-emerald-400"
  defp status_pill_class("rejected"), do: "bg-rose-500/10 text-rose-400"
  defp status_pill_class(_), do: "bg-slate-500/10 text-slate-400"

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  defp format_datetime(_), do: "—"

  defp format_amount(%Decimal{} = amount, currency) do
    sign = if Decimal.negative?(amount), do: "−", else: "+"
    abs_val = Decimal.abs(amount) |> Decimal.to_string(:normal)
    "#{sign} #{abs_val} #{currency}"
  end

  defp format_amount(amount, currency) when is_binary(amount) do
    format_amount(Decimal.new(amount), currency)
  end

  defp format_amount(_, _), do: "—"
end
