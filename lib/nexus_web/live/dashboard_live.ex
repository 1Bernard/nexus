defmodule NexusWeb.DashboardLive do
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_path, "/dashboard")
      |> assign(:market_timeframe, "1D")
      |> assign(:cash_flow_timeframe, "30D")
      |> assign(:stale_data, false)
      |> assign(:market_ticks, [
        %{name: "EUR/USD", price: "1.0854", change: "+0.12%"},
        %{name: "GBP/USD", price: "1.2642", change: "-0.05%"},
        %{name: "USD/JPY", price: "150.32", change: "+0.45%"}
      ])
      |> assign(:risk_summary, %{
        total_exposure: "€4.2M",
        at_risk: "€340K",
        max_loss: "€89K"
      })
      |> assign(:payment_matching, %{
        matched: 847,
        partial: 38,
        unmatched: 15
      })

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6 w-full px-6 pb-12 w-full">
      <%!-- KPI Header Row: Institutional Data Bar (Segmented Control Panel) --%>
      <div class="grid grid-cols-2 lg:grid-cols-5 gap-6 w-full">
        <%!-- 1. Engine Status --%>
        <.dark_card class="p-5 flex flex-col justify-between relative overflow-hidden group">
          <div>
            <h2 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
              Engine Status
            </h2>
            <p class="text-xs text-slate-300 font-medium tracking-wide">Payment Matching</p>
          </div>
          <div class="flex items-center gap-2 mt-4">
            <span class="relative flex h-2 w-2">
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span class="text-[10px] uppercase tracking-wider text-emerald-400 font-bold">
              Active & Scanning
            </span>
          </div>
        </.dark_card>

        <%!-- 2. Matched --%>
        <.kpi_card
          title="Successfully Matched"
          value={to_string(@payment_matching.matched)}
          label="Transactions"
          color="emerald"
          progress
        />

        <%!-- 3. Partial --%>
        <.kpi_card
          title="Partial Matches"
          value={to_string(@payment_matching.partial)}
          label="Requires Review"
          color="amber"
          progress
        />

        <%!-- 4. Alerts --%>
        <.kpi_card
          title="Unmatched Alerts"
          value={to_string(@payment_matching.unmatched)}
          label="Anomalies"
          color="rose"
          progress
        />

        <%!-- 5. Rate & Action --%>
        <.dark_card class="p-5 flex flex-col justify-between relative overflow-hidden bg-indigo-500/5 hover:border-indigo-500/40 transition-colors border-indigo-500/20 cursor-pointer group">
          <div class="flex justify-between items-start">
            <p class="text-[10px] text-indigo-400 uppercase tracking-[0.1em]">Auto-Match Rate</p>
            <span class="hero-bolt w-4 h-4 text-indigo-400/70 group-hover:text-indigo-400 transition-colors">
            </span>
          </div>
          <div class="mt-2 flex items-end justify-between">
            <p class="text-3xl font-bold tracking-tight text-white leading-none">94%</p>
            <span class="text-[10px] text-indigo-300 group-hover:text-white transition-colors uppercase tracking-wider font-semibold flex items-center gap-1 group-hover:translate-x-1 duration-300">
              View All <span class="hero-arrow-right w-3 h-3"></span>
            </span>
          </div>
        </.dark_card>
      </div>

      <%!-- Top Row: High Frequency Data (2/3 & 1/3) --%>
      <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div class="xl:col-span-2 flex flex-col">
          <%!-- Market Prices --%>
          <.dark_card class="p-6 h-full min-h-[300px] flex flex-col relative overflow-hidden group">
            <div class="flex items-center justify-between mb-2">
              <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
                Market Prices
              </h2>
              <div class="flex items-center gap-3">
                <button class="flex items-center gap-1 text-xs font-medium text-slate-200 bg-white/5 hover:bg-white/10 px-2.5 py-1 rounded-md transition-colors border border-white/5">
                  EUR/USD <span class="hero-chevron-down w-3 h-3 text-slate-400"></span>
                </button>
                <.timeframe_selector
                  options={["1H", "4H", "1D", "1W"]}
                  active={@market_timeframe}
                  on_change="set_market_timeframe"
                />
              </div>
            </div>

            <div class="flex items-baseline gap-3 mb-6">
              <span class="text-3xl font-mono tracking-tight text-white">1.0854</span>
              <span class="text-sm font-medium text-emerald-400">+0.12%</span>
            </div>

            <%!-- Mock Candlestick Chart --%>
            <div class="flex-1 relative flex items-end gap-1.5 pb-2 -mx-2 px-2">
              <%!-- SVG Grid lines --%>
              <div class="absolute inset-0 pointer-events-none opacity-20 hidden md:block">
                <svg width="100%" height="100%">
                  <pattern id="grid" width="40" height="20" patternUnits="userSpaceOnUse">
                    <line
                      x1="0"
                      y1="20"
                      x2="40"
                      y2="20"
                      stroke="white"
                      stroke-width="0.5"
                      opacity="0.5"
                    />
                  </pattern>
                  <rect width="100%" height="100%" fill="url(#grid)" />
                </svg>
              </div>

              <%!-- Mock Candles --%>
              <div class="relative w-full h-full flex items-end justify-between px-2">
                <%= for {h, t, top, color} <- [
                  {12, 4, 30, "bg-emerald-500"}, {18, 6, 40, "bg-emerald-500"}, {10, 8, 48, "bg-rose-500"},
                  {24, 12, 38, "bg-emerald-500"}, {16, 6, 28, "bg-rose-500"}, {8, 14, 24, "bg-rose-500"},
                  {20, 8, 30, "bg-emerald-500"}, {28, 10, 45, "bg-emerald-500"}, {14, 12, 60, "bg-rose-500"},
                  {10, 4, 52, "bg-rose-500"}, {22, 10, 50, "bg-emerald-500"}, {32, 14, 65, "bg-emerald-500"},
                  {18, 5, 40, "bg-emerald-500"}
                ] do %>
                  <div
                    class="relative w-2 md:w-3 flex flex-col items-center group/candle cursor-pointer"
                    style={"height: #{h + top}%"}
                  >
                    <div
                      class={[color, "w-px rounded-full opacity-50"]}
                      style={"height: #{t + h + 15}px"}
                    >
                    </div>
                    <div
                      class={[
                        color,
                        "w-full rounded-[1px] absolute shadow-[0_0_8px_rgba(inherit,0.5)]"
                      ]}
                      style={"height: #{h}px; top: #{top}px"}
                    >
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="flex justify-between items-center mt-3 pt-3 border-t border-white/5 relative z-10">
              <p class="text-[11px] font-medium text-slate-400 tracking-wide">
                Last update: 10:42:31 UTC
              </p>
              <div class="flex items-center gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                <span class="text-[10px] uppercase tracking-wider text-emerald-500 font-semibold">
                  Live
                </span>
              </div>
            </div>

            <%!-- Stale Data Alert Overlay --%>
            <div class={[
              "absolute top-4 left-1/2 -translate-x-1/2 bg-amber-500/10 border border-amber-500/20 backdrop-blur-md rounded-xl p-2.5 flex items-center gap-2.5 shadow-xl transition-all hover:bg-amber-500/20 cursor-pointer max-w-[90%]",
              if(!@stale_data, do: "hidden")
            ]}>
              <span class="hero-exclamation-triangle w-4 h-4 text-amber-400 shrink-0"></span>
              <p class="text-[11px] font-medium text-amber-300">
                ⚠ Prices may be up to 15 minutes behind
              </p>
            </div>
          </.dark_card>
        </div>

        <div class="xl:col-span-1 flex flex-col">
          <%!-- Section C: Your Currencies --%>
          <.dark_card class="p-6 h-full flex flex-col justify-between">
            <div>
              <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em] mb-4">
                Your Currencies
              </h2>
              <div class="space-y-3 mb-6">
                <.asset_item
                  :for={tick <- @market_ticks}
                  name={tick.name}
                  price={tick.price}
                  change={tick.change}
                />
              </div>
            </div>

            <div class="bg-white/[0.02] border border-white/5 rounded-2xl p-4 mt-auto">
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.1em] mb-3">
                Your Risk at a Glance
              </h3>
              <div class="space-y-2">
                <div class="flex justify-between text-sm">
                  <span class="text-slate-400">Total Exposure:</span>
                  <span class="font-mono text-white">{@risk_summary.total_exposure}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-slate-400">At Risk:</span>
                  <span class="font-mono text-amber-400">{@risk_summary.at_risk}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-slate-400">Max Loss:</span>
                  <span class="font-mono text-rose-400">{@risk_summary.max_loss}</span>
                </div>
              </div>
            </div>
          </.dark_card>
        </div>
      </div>

      <%!-- Middle Row: Massive Risk Heatmap (Full Width) --%>
      <div class="w-full">
        <.dark_card class="p-6 min-h-[320px]">
          <h2 class="text-[11px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-8">
            Risk Overview (Exposure Map)
          </h2>
          <div class="matrix-container mb-4">
            <%!-- Headers --%>
            <div class="col-span-1"></div>
            <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              EUR
            </div>
            <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              USD
            </div>
            <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              GBP
            </div>
            <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              JPY
            </div>
            <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              CHF
            </div>

            <%!-- Row 1: Munich HQ --%>
            <div class="text-xs font-medium text-slate-400 self-center text-right pr-4">
              Munich HQ
            </div>
            <div class="bg-indigo-500/10 rounded-lg h-12 border border-indigo-500/10 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair group relative">
              <div class="absolute inset-x-0 bottom-full mb-2 hidden group-hover:block bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-lg p-2 text-center text-xs shadow-xl z-20">
                <div class="font-bold text-white">€145,000</div>
                <div class="text-[10px] text-slate-400 mt-1">Munich HQ · EUR</div>
              </div>
            </div>
            <div class="bg-indigo-500/30 rounded-lg h-12 border border-indigo-500/20 hover:bg-indigo-500/40 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair relative group">
              <div class="absolute inset-x-0 bottom-full mb-2 hidden group-hover:block bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-lg p-2 text-center text-xs shadow-xl z-20 w-32 -ml-8">
                <div class="font-bold text-white">$450,000</div>
                <div class="text-[10px] text-slate-400 mt-1">Munich HQ · USD</div>
              </div>
            </div>
            <div class="bg-indigo-500/50 rounded-lg h-12 border border-indigo-500/30 hover:bg-indigo-500/60 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair">
            </div>
            <div class="bg-amber-500/50 rounded-lg h-12 shadow-[0_0_15px_-3px_rgba(245,158,11,0.3)] hover:bg-amber-400 hover:-translate-y-1 hover:shadow-[0_8px_25px_-4px_rgba(245,158,11,0.5)] transition-all cursor-crosshair border border-amber-500/20 relative group">
              <div class="absolute inset-x-0 bottom-full mb-2 hidden group-hover:block bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-lg p-2 text-center text-xs shadow-xl z-20 w-32 -ml-8">
                <div class="font-bold text-amber-400">¥10,000,000</div>
                <div class="text-[10px] text-slate-400 mt-1">Munich HQ · JPY</div>
                <div class="text-[9px] text-amber-500/70 mt-1 border-t border-amber-500/20 pt-1">
                  Elevated Risk Limit
                </div>
              </div>
            </div>
            <div class="bg-indigo-500/10 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>

            <%!-- Row 2: Tokyo Branch --%>
            <div class="text-xs font-medium text-slate-400 self-center text-right pr-4">
              Tokyo Branch
            </div>
            <div class="bg-indigo-500/20 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>
            <div class="bg-rose-500/70 rounded-lg h-12 shadow-[0_0_15px_-3px_rgba(244,63,94,0.3)] hover:bg-rose-400 hover:-translate-y-1 hover:shadow-[0_8px_25px_-4px_rgba(244,63,94,0.5)] transition-all cursor-crosshair border border-rose-500/40 relative group">
              <div class="absolute inset-x-0 bottom-full mb-2 hidden group-hover:block bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-lg p-2 text-center text-xs shadow-xl z-20 w-32 -ml-8">
                <div class="font-bold text-rose-400">$1,200,000</div>
                <div class="text-[10px] text-slate-400 mt-1">Tokyo Branch · USD</div>
                <div class="text-[9px] text-rose-500/70 mt-1 border-t border-rose-500/20 pt-1">
                  Critical Limit Reached
                </div>
              </div>
            </div>
            <div class="bg-indigo-500/10 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>
            <div class="bg-indigo-500/60 rounded-lg h-12 hover:bg-indigo-500/70 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/40">
            </div>
            <div class="bg-indigo-500/20 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>

            <%!-- Row 3: London Ltd --%>
            <div class="text-xs font-medium text-slate-400 self-center text-right pr-4">
              London Ltd
            </div>
            <div class="bg-indigo-500/40 rounded-lg h-12 hover:bg-indigo-500/50 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/20">
            </div>
            <div class="bg-indigo-500/20 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>
            <div class="bg-indigo-500/80 rounded-lg h-12 hover:bg-indigo-500/90 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/50">
            </div>
            <div class="bg-indigo-500/10 rounded-lg h-12 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/10">
            </div>
            <div class="bg-indigo-500/30 rounded-lg h-12 hover:bg-indigo-500/40 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)] transition-all cursor-crosshair border border-indigo-500/20">
            </div>
          </div>

          <div class="flex items-center justify-center gap-8 mt-8 pt-6 border-t border-white/5">
            <div class="flex items-center gap-2 text-[10px] text-slate-400 uppercase tracking-wider">
              <span class="w-3 h-3 rounded bg-indigo-500/50 border border-indigo-500/20"></span>
              Normal Exposure
            </div>
            <div class="flex items-center gap-2 text-[10px] text-slate-400 uppercase tracking-wider">
              <span class="w-3 h-3 rounded bg-amber-500/50 border border-amber-500/20"></span>
              Elevated Risk
            </div>
            <div class="flex items-center gap-2 text-[10px] text-slate-400 uppercase tracking-wider">
              <span class="w-3 h-3 rounded bg-rose-500/50 border border-rose-500/20"></span>
              Critical Limit Approaching
            </div>
          </div>
        </.dark_card>
      </div>

      <%!-- Lower Row: Trends & Activity (2/3 & 1/3) --%>
      <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div class="xl:col-span-2 flex flex-col">
          <.dark_card class="p-6 min-h-[300px] h-full flex flex-col relative overflow-hidden group">
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
                Cash Flow Outlook
              </h2>
              <div class="flex items-center gap-4">
                <div class="flex items-center gap-2 bg-slate-900/50 border border-slate-700/50 rounded-md px-3 py-1.5 cursor-pointer hover:bg-slate-800/50 transition-colors">
                  <span class="hero-calendar w-3.5 h-3.5 text-slate-400"></span>
                  <span class="text-[11px] font-medium text-slate-300">Oct 1 - Oct 31</span>
                  <span class="hero-chevron-down w-3 h-3 text-slate-500 ml-1"></span>
                </div>
                <.timeframe_selector
                  options={["7D", "14D", "30D", "90D"]}
                  active={@cash_flow_timeframe}
                  on_change="set_cash_flow_timeframe"
                  variant="solid"
                />
                <button class="flex items-center gap-1.5 text-[11px] font-medium text-slate-300 hover:text-white bg-slate-800/40 hover:bg-slate-700/50 px-3 py-1.5 rounded-md transition-colors border border-slate-700/50 group">
                  <span class="hero-arrow-down-tray w-3.5 h-3.5 text-slate-400 group-hover:text-indigo-400 transition-colors">
                  </span>
                  CSV
                </button>
              </div>
            </div>

            <%!-- Mock Area Chart --%>
            <div class="flex-1 relative -mx-6 px-6 pb-4">
              <svg
                class="absolute inset-0 w-full h-full"
                preserveAspectRatio="none"
                viewBox="0 0 100 100"
              >
                <path
                  d="M0,80 L20,75 L40,85 L60,40 L80,50 L100,20 L100,100 L0,100 Z"
                  fill="url(#cf-gradient)"
                  opacity="0.3"
                />
                <path
                  d="M0,80 L20,75 L40,85 L60,40 L80,50 L100,20"
                  fill="none"
                  stroke="#6366F1"
                  stroke-width="2"
                />
                <path
                  d="M0,70 L20,60 L40,70 L60,20 L80,30 L100,0"
                  fill="none"
                  stroke="#6366F1"
                  stroke-width="1"
                  stroke-dasharray="2 4"
                  opacity="0.4"
                />
                <path
                  d="M0,90 L20,90 L40,100 L60,60 L80,70 L100,40"
                  fill="none"
                  stroke="#6366F1"
                  stroke-width="1"
                  stroke-dasharray="2 4"
                  opacity="0.4"
                />
                <line
                  x1="40"
                  y1="0"
                  x2="40"
                  y2="100"
                  stroke="#F43F5E"
                  stroke-width="1.5"
                  stroke-dasharray="4 2"
                  opacity="0.8"
                />
                <circle cx="40" cy="85" r="3" fill="#F43F5E" />
                <defs>
                  <linearGradient id="cf-gradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#6366F1" stop-opacity="0.5" />
                    <stop offset="100%" stop-color="#6366F1" stop-opacity="0.0" />
                  </linearGradient>
                </defs>
              </svg>
              <div class="absolute bottom-4 left-6 right-6 flex justify-between text-[9px] text-slate-500 uppercase tracking-wider font-mono">
                <span>Today</span><span>+15d</span><span>+30d</span>
              </div>
              <div class="absolute top-1/4 left-[35%] w-32 bg-rose-500/10 border border-rose-500/30 backdrop-blur-md p-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity">
                <p class="text-[10px] font-semibold text-rose-400 leading-tight">Cash Gap Alert</p>
                <p class="text-[9px] text-rose-300/80 mt-0.5">Projected shortfall: €142K on Mar 7</p>
              </div>
            </div>

            <div class="flex justify-between items-center mt-3 pt-3 border-t border-white/5 relative z-10">
              <p class="text-[11px] font-medium text-slate-400 tracking-wide">
                Last updated: 10:45 UTC
              </p>
            </div>
          </.dark_card>
        </div>

        <div class="xl:col-span-1 flex flex-col">
          <%!-- Section E: Recent Activity Feed --%>
          <.dark_card class="p-6 h-full">
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
                Recent Activity
              </h2>
              <button class="text-[10px] text-indigo-400 hover:text-indigo-300 transition-colors uppercase tracking-wider font-semibold">
                View All
              </button>
            </div>

            <div class="space-y-5 relative max-h-[400px] overflow-y-auto pr-2 scroll-soft">
              <div class="absolute left-[11px] top-2 bottom-2 w-px bg-white/5"></div>

              <.activity_item
                icon="hero-document-text"
                color="indigo"
                title="New invoice received —"
                id_str="#3847"
                amount_str="€24,500"
                time_ago="2 min ago"
              />

              <.activity_item
                icon="hero-check-circle"
                color="emerald"
                title="✓ Payment matched to invoice"
                id_str="#3842"
                time_ago="15 min ago"
              />

              <.activity_item
                icon="hero-arrow-up-tray"
                color="white"
                title="Statement uploaded"
                subtitle="Q3_Barclays_EUR.csv"
                time_ago="1 hour ago"
              />

              <.activity_item
                icon="hero-exclamation-triangle"
                color="amber"
                title="⚠ Something looks unusual"
                subtitle="JPY invoice from Munich HQ"
                time_ago="3 hours ago"
              />

              <div class="absolute bottom-0 left-0 right-0 h-24 bg-gradient-to-t from-[#0f172a] via-[#0f172a]/80 to-transparent pointer-events-none z-10">
              </div>
            </div>
          </.dark_card>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_market_timeframe", %{"tf" => tf}, socket) do
    {:noreply, assign(socket, :market_timeframe, tf)}
  end

  def handle_event("set_cash_flow_timeframe", %{"tf" => tf}, socket) do
    {:noreply, assign(socket, :cash_flow_timeframe, tf)}
  end
end
