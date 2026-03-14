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
        "flex-shrink-0 w-16 h-7 rounded-md flex items-center justify-center text-[9px] font-black tracking-[0.2em] uppercase shadow-sm transition-all group-hover:scale-105",
        format_badge_class(@statement.format)
      ]}>
        {@statement.format}
      </div>

      <%!-- Filename + meta --%>
      <div class="flex-1 min-w-0">
        <p class="text-sm text-white font-medium truncate">{@statement.filename}</p>
        <%= if @statement.status == "rejected" do %>
          <p class="text-[10px] text-rose-400 mt-0.5 font-bold flex items-center gap-1.5">
            <span class="hero-exclamation-circle w-3 h-3"></span>
            {@statement.error_message || "Ingestion failed"}
          </p>
        <% else %>
          <div class="flex items-center gap-2 mt-0.5">
            <p class="text-[10px] text-slate-500 font-mono">
              Uploaded {format_datetime(@statement.uploaded_at)}
            </p>
            <span class="w-1 h-1 rounded-full bg-slate-700"></span>
            <p class="text-[9px] font-bold text-slate-400 uppercase tracking-widest bg-white/5 px-1.5 py-0.5 rounded">
              {@statement.org_name || "Nexus Platform"}
            </p>
          </div>
        <% end %>
      </div>

      <%!-- Line count --%>
      <div class="text-right flex-shrink-0">
        <p class="text-sm font-semibold text-white tabular-nums">{@statement.line_count}</p>
        <p class="text-[10px] text-slate-500 uppercase tracking-wider">lines</p>
      </div>

      <%!-- Match Rate progress bar --%>
      <div class="hidden md:flex flex-col gap-1.5 w-32 flex-shrink-0">
        <div class="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
          <span class="text-slate-500">Match Rate</span>
          <span class="text-emerald-400 font-mono">{calculate_match_rate(@statement)}%</span>
        </div>
        <div class="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
          <div
            class="h-full bg-emerald-500 rounded-full transition-all"
            style={"width: #{calculate_match_rate(@statement)}%"}
          />
        </div>
      </div>

      <%!-- Status pill --%>
      <div class="flex items-center gap-3">
        <%= if @statement.overlap_warning do %>
          <div class="group/warn relative" title="Potential duplicate statement detected">
            <span class="hero-exclamation-triangle w-4 h-4 text-amber-500 cursor-help"></span>
            <div class="absolute bottom-full mb-2 hidden group-hover/warn:block bg-slate-900 border border-white/10 rounded-lg p-2 text-[10px] text-amber-200 w-32 shadow-xl z-30">
              Potential duplicate statement detected by filename.
            </div>
          </div>
        <% end %>

        <div class={[
          "flex-shrink-0 px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
          status_pill_class(@statement.status)
        ]}>
          {@statement.status}
        </div>
      </div>
    </div>
    """
  end

  @doc "Renders a parsed transaction line row."
  attr :line, :map, required: true

  def statement_line_row(assigns) do
    ~H"""
    <div class={[
      "flex flex-col px-4 py-2.5 text-xs border-b border-white/[0.04] last:border-0",
      @line.error_message && "bg-rose-500/5"
    ]}>
      <div class="flex items-center gap-4">
        <span class="w-24 flex-shrink-0 text-slate-400 font-mono tabular-nums">{@line.date}</span>
        <span class="flex-1 text-slate-300 truncate">{@line.narrative}</span>
        <span class="w-28 text-right flex-shrink-0 font-mono font-semibold tabular-nums text-white">
          {format_amount(@line.amount, @line.currency)}
        </span>
      </div>
      <%= if @line.error_message do %>
        <div class="mt-1 ml-28 flex items-center gap-1.5">
          <span class="hero-exclamation-circle w-3 h-3 text-rose-400"></span>
          <span class="text-[10px] text-rose-400/80 font-medium italic">{@line.error_message}</span>
        </div>
      <% end %>
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
    do: "bg-indigo-500/10 text-indigo-400 ring-1 ring-indigo-500/30 font-mono"

  defp format_badge_class("csv"),
    do: "bg-cyan-500/10 text-cyan-400 ring-1 ring-cyan-500/30 font-mono"

  defp format_badge_class("rejected"),
    do: "bg-rose-500/10 text-rose-400 ring-1 ring-rose-500/30 font-mono"

  defp format_badge_class(_), do: "bg-slate-500/10 text-slate-400 ring-1 ring-slate-500/20"

  defp status_pill_class("uploaded"),
    do: "bg-emerald-500/10 text-emerald-400 ring-1 ring-emerald-500/20"

  defp status_pill_class("rejected"),
    do: "bg-rose-500/10 text-rose-400 ring-1 ring-rose-500/20"

  defp status_pill_class(_), do: "bg-slate-500/10 text-slate-400 ring-1 ring-slate-500/20"

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")
  defp format_datetime(_), do: "—"

  def format_amount(%Decimal{} = amount, currency) do
    sign = if Decimal.negative?(amount), do: "−", else: "+"
    abs_val = Decimal.abs(amount) |> Decimal.round(2) |> Decimal.to_string(:normal)

    # Ensure .00 if needed (Decimal.to_string might drop it if it's .0)
    abs_val =
      case String.split(abs_val, ".") do
        [whole, decimal] -> whole <> "." <> String.pad_trailing(decimal, 2, "0")
        [whole] -> whole <> ".00"
      end

    "#{sign} #{abs_val} #{currency}"
  end

  def format_amount(amount, currency) when is_binary(amount) do
    case parse_decimal(amount) do
      {:ok, dec} -> format_amount(dec, currency)
      _ -> "—"
    end
  end

  def format_amount(_, _), do: "—"

  defp parse_decimal(nil), do: :error
  defp parse_decimal(val) when is_struct(val, Decimal), do: {:ok, val}

  defp parse_decimal(val) when is_binary(val) do
    case Decimal.cast(val) do
      {:ok, dec} -> {:ok, dec}
      :error -> :error
    end
  end

  defp calculate_match_rate(%{line_count: 0}), do: 0

  defp calculate_match_rate(%{line_count: total, matched_count: matched}) do
    round(matched / total * 100)
  end
end
