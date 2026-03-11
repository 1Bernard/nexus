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
    <div class="relative rounded-2xl border border-white/10 bg-[#1A1F2B]/60 backdrop-blur-2xl overflow-hidden group shadow-[0_8px_32px_rgba(0,0,0,0.5)] hover:border-white/20 transition-all duration-500">
      <%!-- Subtle top glow --%>
      <div class="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-[1px] bg-gradient-to-r from-transparent via-indigo-500/30 to-transparent"></div>

      <div class="p-8 lg:p-12 relative z-10">
        <%= if @label do %>
          <div class="text-xs font-semibold tracking-wider text-indigo-400 uppercase mb-8 flex items-center gap-3">
            <span class="w-6 h-[2px] bg-indigo-500/30 rounded-full"></span>
            {@label}
          </div>
        <% end %>

        {render_slot(@inner_block)}
      </div>

      <%= if @footer do %>
        <div class="border-t border-white/5 p-6 bg-[#0B0E14]/50 backdrop-blur-md relative z-10">
          {render_slot(@footer)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  The Premium Isometric Architectural Viewer.
  """
  def partition_cube(assigns) do
    ~H"""
    <div class="w-full max-w-sm mx-auto aspect-square relative flex items-center justify-center pointer-events-none">
      <%!-- Layer 3: Application / Identity --%>
      <div class="absolute w-48 h-48 bg-indigo-500/10 border border-indigo-500/30 rounded-3xl transform rotate-12 rotate-x-[60deg] shadow-[0_20px_50px_rgba(99,102,241,0.15)] transition-all duration-700 ease-out flex items-center justify-center backdrop-blur-md z-30 group-hover:-translate-y-8 group-hover:border-indigo-400/50">
        <div class="w-24 h-24 bg-white/5 rounded-full blur-xl animate-pulse"></div>
        <div class="absolute text-indigo-400 font-semibold text-[10px] bottom-4 left-4 tracking-wider">IDENTITY LAYER</div>
      </div>

      <%!-- Layer 2: Compute / Event Store --%>
      <div class="absolute w-56 h-56 bg-cyan-500/5 border border-cyan-500/20 rounded-3xl transform rotate-12 rotate-x-[60deg] translate-y-6 shadow-[0_20px_50px_rgba(6,182,212,0.1)] transition-all duration-700 ease-out flex items-center justify-center backdrop-blur-md z-20 group-hover:translate-y-2 group-hover:border-cyan-400/40">
        <div class="absolute text-cyan-500/50 font-semibold text-[10px] bottom-4 right-4 tracking-wider">EVENT STORE</div>
      </div>

      <%!-- Layer 1: Hardware/Storage --%>
      <div class="absolute w-64 h-64 bg-slate-800/30 border border-white/5 rounded-3xl transform rotate-12 rotate-x-[60deg] translate-y-12 shadow-2xl flex items-center justify-center backdrop-blur-md z-10 group-hover:translate-y-16">
         <div class="absolute text-slate-500 font-semibold text-[10px] top-4 left-4 tracking-wider">SECURE ENCLAVE</div>
      </div>

      <%!-- Connecting Beam --%>
      <div class="absolute w-[1px] h-32 bg-gradient-to-b from-indigo-400 via-cyan-400 to-transparent left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 -z-10 blur-[1px] opacity-0 group-hover:opacity-100 transition-opacity duration-700"></div>
    </div>
    """
  end

  @doc """
  The High-Fidelity Transaction Pipeline Exhibit.
  Replaces the legacy terminal ledger stream with premium glassmorphic transaction cards.
  """
  def ledger_stream(assigns) do
    ~H"""
    <div class="w-full h-[400px] overflow-hidden relative flex items-center justify-center bg-transparent">
      <%!-- Clean gradient bg --%>
      <div class="absolute inset-0 bg-gradient-to-b from-transparent via-cyan-500/5 to-transparent"></div>

      <%!-- Sleek Pipeline Track --%>
      <div class="absolute top-1/2 left-0 w-full h-[1px] bg-white/5"></div>
      <div class="absolute top-1/2 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-indigo-400/50 to-transparent scale-x-75 blur-sm"></div>

      <%!-- Pipeline Track --%>
      <div class="relative w-full h-full flex items-center">
        <div class="flex animate-[slide-left_25s_linear_infinite] w-max select-none items-center">
          <% transactions = [
            %{
              type: "SAP S/4HANA Sync",
              ref: "TX-992381",
              amount: "$2.4M",
              status: "Settled",
              color: "emerald",
              icon: "✓"
            },
            %{
              type: "Cross-Border Wire",
              ref: "SWIFT-US2EU",
              amount: "€850k",
              status: "Verifying",
              color: "indigo",
              icon: "↻"
            },
            %{
              type: "Ledger Consensus",
              ref: "BLK-884A",
              amount: "Validated",
              status: "Secured",
              color: "cyan",
              icon: "◆"
            },
            %{
              type: "Payroll Escrow",
              ref: "ESC-03",
              amount: "$1.2M",
              status: "Held",
              color: "slate",
              icon: "🔒"
            }
          ] %>

          <%= for _i <- 1..3 do %>
            <%= for tx <- transactions do %>
              <%!-- Premium Dark Mode Cards --%>
              <div class="mx-4 w-60 bg-[#1A1F2B]/80 border border-white/10 rounded-2xl p-5 shadow-[0_8px_30px_rgba(0,0,0,0.5)] flex flex-col gap-4 group hover:-translate-y-2 hover:border-indigo-500/30 hover:shadow-[0_20px_40px_rgba(99,102,241,0.15)] transition-all duration-500 relative overflow-hidden backdrop-blur-xl">
                <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-white/10 to-transparent group-hover:via-indigo-400/50 transition-colors"></div>

                <div class="flex justify-between items-center">
                  <div class={"w-10 h-10 rounded-xl bg-#{tx.color}-500/10 flex items-center justify-center text-#{tx.color}-400 text-lg border border-#{tx.color}-500/20 shadow-[inset_0_0_15px_rgba(255,255,255,0.02)]"}>
                    {tx.icon}
                  </div>
                  <div class="text-[11px] font-semibold text-slate-400 tracking-wider uppercase bg-white/5 border border-white/5 px-2 py-1 rounded-md">{tx.ref}</div>
                </div>
                <div>
                  <div class="text-white font-bold text-xl mb-1">{tx.amount}</div>
                  <div class="text-slate-400 text-sm font-medium">{tx.type}</div>
                </div>
                <div class="pt-4 border-t border-white/5 flex items-center justify-between mt-1">
                  <div class={"text-xs font-bold tracking-wider uppercase text-#{tx.color}-400"}>
                    {tx.status}
                  </div>
                  <div class={"w-2 h-2 rounded-full bg-#{tx.color}-500 shadow-[0_0_8px_rgba(0,0,0,0.1)] relative"}>
                    <div class={"absolute inset-0 rounded-full bg-#{tx.color}-400 animate-ping opacity-75"}></div>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Edge Fades matching the container bg --%>
      <div class="absolute left-0 top-0 bottom-0 w-32 bg-gradient-to-r from-[#0B0E14] to-transparent z-10 pointer-events-none"></div>
      <div class="absolute right-0 top-0 bottom-0 w-32 bg-gradient-to-l from-[#0B0E14] to-transparent z-10 pointer-events-none"></div>
    </div>
    """
  end

  @doc """
  Premium Secure Authentication Display.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true
  slot :hidden_content, required: true

  def exhibit_scanning_mask(assigns) do
    ~H"""
    <div id={@id} class={["relative w-full max-w-sm mx-auto group cursor-pointer", @class]} data-scan="true">
      <div class="relative z-10 p-8 rounded-2xl border border-white/10 bg-[#1A1F2B]/80 backdrop-blur-xl shadow-2xl transition-all duration-500 group-hover:border-indigo-500/30 group-hover:shadow-[0_20px_50px_rgba(99,102,241,0.15)]">
        <div class="flex flex-col items-center text-center">
          <%!-- Biometric Icon Container --%>
          <div class="w-20 h-20 rounded-full bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center mb-6 relative overflow-hidden group-hover:scale-105 transition-transform duration-500">
            <%!-- Shimmer effect --%>
            <div class="absolute inset-0 bg-gradient-to-b from-transparent via-indigo-400/30 to-transparent -translate-y-full hover:translate-y-full transition-all duration-[2s] ease-in-out"></div>
            <%!-- Minimalist Face/Touch ID icon representation --%>
            <div class="w-10 h-10 flex items-center justify-center border border-indigo-400/50 rounded-xl rounded-tr-3xl rotate-45 transform group-hover:border-indigo-400 transition-colors"></div>
            <%!-- Inner pulsing dot --%>
            <div class="absolute w-2 h-2 bg-indigo-400 rounded-full opacity-50 animate-ping"></div>
          </div>

          <h4 class="text-white font-semibold text-lg mb-2">{@label}</h4>
          {render_slot(@inner_block)}

          <%!-- Success State (simulating scanner success via group hover for the landing page) --%>
          <div class="w-full mt-6 pt-6 border-t border-white/10 opacity-0 transform translate-y-2 transition-all duration-500 group-hover:opacity-100 group-hover:translate-y-0">
             <div class="flex items-center justify-center gap-2 text-emerald-400 mb-2">
               <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
               </svg>
               <span class="font-bold text-sm">Authenticated</span>
             </div>
             {render_slot(@hidden_content)}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
