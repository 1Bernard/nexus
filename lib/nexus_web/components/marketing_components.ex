defmodule NexusWeb.MarketingComponents do
  @moduledoc false
  use Phoenix.Component

  # ══════════════════════════════════════════════════════════════
  # 7. EDITORIAL MUSEUM
  # ══════════════════════════════════════════════════════════════

  @doc """
  Renders a structured archival partition with 1px borders and metadata.
  """
  attr :title, :string, default: nil
  attr :id, :string, default: nil
  attr :label, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def archival_partition(assigns) do
    ~H"""
    <div
      id={@id}
      class={["border border-white/10 bg-white/[0.02] p-6 lg:p-10 relative group", @class]}
    >
      <div class="absolute top-0 left-0 bg-white/20 h-[1px] w-8 transition-all group-hover:w-full">
      </div>
      <div class="absolute top-0 left-0 bg-white/20 w-[1px] h-8 transition-all group-hover:h-full">
      </div>

      <%= if @label do %>
        <div class="absolute -top-3 left-6 px-2 bg-[#0B0E14] text-[9px] font-mono tracking-[0.3em] text-slate-500 uppercase">
          {@label}
        </div>
      <% end %>

      <%= if @title do %>
        <h3 class="text-xs font-mono tracking-[0.2em] text-slate-400 uppercase mb-8 flex items-center gap-3">
          <span class="w-1.5 h-1.5 rounded-full bg-cyan-500"></span>
          {@title}
        </h3>
      <% end %>

      {render_slot(@inner_block)}

      <div class="absolute bottom-4 right-4 text-[8px] font-mono text-white/5 opacity-0 group-hover:opacity-100 transition-opacity">
        REF: NEX-{String.slice(@id || "0000", -4..-1)}
      </div>
    </div>
    """
  end

  @doc """
  Renders an asymmetric editorial background grid.
  """
  def editorial_grid(assigns) do
    ~H"""
    <div class="absolute inset-0 pointer-events-none opacity-[0.03] overflow-hidden">
      <div class="absolute inset-0 border-l border-white h-full left-[20%]"></div>
      <div class="absolute inset-0 border-l border-white h-full left-[50%]"></div>
      <div class="absolute inset-0 border-l border-white h-full left-[80%]"></div>
      <div class="absolute inset-0 border-t border-white w-full top-[30%]"></div>
      <div class="absolute inset-0 border-t border-white w-full top-[70%]"></div>
    </div>
    """
  end

  @doc """
  Zero-latency precision cursor crosshair.
  """
  def precision_cursor(assigns) do
    ~H"""
    <div
      id="precision-cursor"
      phx-hook="CursorFollower"
      class="fixed inset-0 pointer-events-none z-[9999]"
    >
      <div
        id="cursor-ring"
        class="absolute w-12 h-12 border border-white/20 rounded-full -translate-x-1/2 -translate-y-1/2 flex items-center justify-center transition-transform duration-75"
      >
        <div class="w-full h-[1px] bg-white/10 scale-x-[0.2]"></div>
        <div class="h-full w-[1px] bg-white/10 scale-y-[0.2] absolute"></div>
      </div>
      <div
        id="cursor-dot"
        class="absolute w-1.5 h-1.5 bg-white rounded-full -translate-x-1/2 -translate-y-1/2"
      >
      </div>
    </div>
    """
  end

  @doc """
  A premium container for interactive exhibits.
  """
  attr :label, :string, default: nil
  slot :inner_block, required: true
  slot :footer

  def exhibit_container(assigns) do
    ~H"""
    <div class="relative border border-white/5 bg-white/[0.01] overflow-hidden group">
      <div class="absolute inset-0 volumetric-nebula opacity-20 pointer-events-none"></div>

      <div class="p-8 lg:p-12 relative z-10">
        <%= if @label do %>
          <div class="text-[9px] font-mono tracking-[0.4em] text-indigo-500/50 uppercase mb-12 flex items-center gap-4">
            <span class="w-8 h-[1px] bg-indigo-500/20"></span>
            {@label}
          </div>
        <% end %>

        {render_slot(@inner_block)}
      </div>

      <%= if @footer do %>
        <div class="border-t border-white/5 p-6 bg-black/20 backdrop-blur-sm relative z-10">
          {render_slot(@footer)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  The 3D Partition Viewer Exhibit.
  """
  def partition_cube(assigns) do
    ~H"""
    <div
      class="exhibit-3d-scene mx-auto mb-12 interactive"
      phx-hook="CubeController"
      id="nexus-core-cube"
    >
      <div class="exhibit-cube">
        <div class="cube-face face-front">
          <span class="text-[8px] font-mono opacity-20">FRONT</span>
        </div>
        <div class="cube-face face-back">
          <span class="text-[8px] font-mono opacity-20">BACK</span>
        </div>
        <div class="cube-face face-right">
          <span class="text-[8px] font-mono opacity-20">RIGHT</span>
        </div>
        <div class="cube-face face-left">
          <span class="text-[8px] font-mono opacity-20">LEFT</span>
        </div>
        <div class="cube-face face-top"><span class="text-[8px] font-mono opacity-20">TOP</span></div>
        <div class="cube-face face-bottom">
          <span class="text-[8px] font-mono opacity-20">BOTTOM</span>
        </div>

        <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div class="w-12 h-12 border border-indigo-500/50 rotate-45 animate-pulse"></div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  The High-Fidelity Transaction Pipeline Exhibit.
  Replaces the legacy terminal ledger stream with premium glassmorphic transaction cards.
  """
  def ledger_stream(assigns) do
    ~H"""
    <div class="w-full h-[400px] overflow-hidden relative flex items-center justify-center">
      <%!-- Background Grid/Glow --%>
      <div class="absolute inset-0 bg-[url('/images/grid-pattern.svg')] opacity-10"></div>
      <div class="absolute top-1/2 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-indigo-500/50 to-transparent">
      </div>
      <div class="absolute top-1/2 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-cyan-400/20 to-transparent blur-sm">
      </div>

      <%!-- Pipeline Track --%>
      <div class="relative w-full h-full flex items-center">
        <div class="flex animate-[slide-left_20s_linear_infinite] w-max select-none">
          <% transactions = [
            %{
              type: "SAP BAPI Sync",
              ref: "DOC-992381",
              amount: "$2.4M",
              status: "Settled",
              color: "emerald",
              icon: "✓"
            },
            %{
              type: "Cross-Border Wire",
              ref: "SWIFT-US2EU",
              amount: "€850k",
              status: "Processing",
              color: "indigo",
              icon: "↻"
            },
            %{
              type: "Ledger Consensus",
              ref: "BLOCK-884A",
              amount: "Validated",
              status: "Secured",
              color: "cyan",
              icon: "◆"
            },
            %{
              type: "Payroll Escrow",
              ref: "ESC-2026-03",
              amount: "$1.2M",
              status: "Held",
              color: "slate",
              icon: "🔒"
            }
          ] %>

          <%= for _i <- 1..3 do %>
            <%= for tx <- transactions do %>
              <div class="mx-6 w-64 bg-[#0B0E14]/80 backdrop-blur-xl border border-white/10 rounded-2xl p-4 shadow-[0_8px_30px_rgba(0,0,0,0.5)] flex flex-col gap-3 group hover:border-white/20 hover:-translate-y-1 transition-all duration-300">
                <div class="flex justify-between items-start">
                  <div class={"w-8 h-8 rounded-full bg-#{tx.color}-500/10 flex items-center justify-center text-#{tx.color}-400 text-sm border border-#{tx.color}-500/20"}>
                    {tx.icon}
                  </div>
                  <div class="text-[10px] font-mono text-slate-500">{tx.ref}</div>
                </div>
                <div>
                  <div class="text-white font-semibold text-sm mb-0.5">{tx.amount}</div>
                  <div class="text-slate-400 text-xs">{tx.type}</div>
                </div>
                <div class="pt-3 border-t border-white/5 flex items-center justify-between">
                  <div class={"text-[10px] font-bold tracking-wider uppercase text-#{tx.color}-400"}>
                    {tx.status}
                  </div>
                  <div class={"w-1.5 h-1.5 rounded-full bg-#{tx.color}-500 shadow-[0_0_8px_currentColor]"}>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Edge Fades --%>
      <div class="absolute left-0 top-0 bottom-0 w-32 bg-gradient-to-r from-[#0B0E14] to-transparent z-10">
      </div>
      <div class="absolute right-0 top-0 bottom-0 w-32 bg-gradient-to-l from-[#0B0E14] to-transparent z-10">
      </div>
    </div>
    """
  end

  @doc """
  The Biometric Scanner Reveal Exhibit.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true
  slot :hidden_content, required: true

  def exhibit_scanning_mask(assigns) do
    ~H"""
    <div id={@id} class={["relative scanner-reveal interactive group", @class]} data-scan="true">
      <div class="relative z-10 p-6 lg:p-10 border border-white/5 bg-white/[0.02]">
        <div class="text-[8px] font-mono text-indigo-500/50 uppercase mb-8">{@label}</div>

        {render_slot(@inner_block)}

        <div class="mt-8 pt-8 border-t border-white/5 opacity-0 translate-y-4 transition-all duration-700 group-[.scanned]:opacity-100 group-[.scanned]:translate-y-0">
          <div class="text-[8px] font-mono text-indigo-400 uppercase mb-4">
            VERIFIED_ENCLAVE // SECURE
          </div>
          <div class="font-mono text-[10px] text-slate-400 space-y-2">
            {render_slot(@hidden_content)}
          </div>
        </div>
      </div>

      <div class="absolute inset-0 pointer-events-none overflow-hidden opacity-0 group-hover:opacity-100 transition-opacity">
        <div class="scanner-beam h-full animate-[shimmer_3s_infinite]"></div>
      </div>
    </div>
    """
  end
end
