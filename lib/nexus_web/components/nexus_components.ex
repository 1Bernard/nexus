defmodule NexusWeb.NexusComponents do
  @moduledoc """
  Shared UI components for the Nexus dark-theme design system.

  These components provide the institutional aesthetic used across
  all domain-specific LiveViews (Identity, Treasury, ERP, etc.).
  Auto-imported via `html_helpers/0` in `NexusWeb`.
  """
  use Phoenix.Component

  @doc """
  Renders the full-page dark wrapper used by all Nexus views.

  ## Examples

      <.dark_page>
        <h1>Content here</h1>
      </.dark_page>

      <.dark_page class="flex items-center justify-center p-3">
        <h1>Centered content</h1>
      </.dark_page>
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dark_page(assigns) do
    ~H"""
    <div class={[
      "min-h-screen bg-[#0B0E14] text-slate-100 font-sans selection:bg-indigo-500/40",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a dark card panel — the primary container for content sections.

  ## Examples

      <.dark_card>
        <h2>Market Activity</h2>
      </.dark_card>

      <.dark_card class="p-8 min-h-[400px]">
        <h2>Large Card</h2>
      </.dark_card>
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dark_card(assigns) do
    ~H"""
    <div class={[
      "bg-[#14181F] border border-white/[0.06] rounded-[2rem]",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders an asset ticker item with name, price, and change indicator.

  Supports positive (+) and negative change values with appropriate coloring.

  ## Examples

      <.asset_item name="BTC/USD" price="68,432.12" change="+2.4%" />
  """
  attr :name, :string, required: true
  attr :price, :string, required: true
  attr :change, :string, required: true

  def asset_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-3 rounded-2xl bg-white/[0.02] hover:bg-white/[0.04] transition-colors group cursor-pointer border border-transparent hover:border-white/5">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-xl bg-white/5 flex items-center justify-center text-xs font-bold text-slate-400">
          {@name |> String.split("/") |> List.first()}
        </div>
        <span class="text-sm font-medium">{@name}</span>
      </div>
      <div class="text-right">
        <div class="text-sm font-mono">{@price}</div>
        <div class={[
          "text-[10px] font-bold",
          if(@change =~ "+", do: "text-emerald-400", else: "text-rose-400")
        ]}>
          {@change}
        </div>
      </div>
    </div>
    """
  end
end
