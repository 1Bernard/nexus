defmodule NexusWeb.Tenant.DashboardLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury
  alias Nexus.ERP
  alias Nexus.Treasury.Gateways.PriceCache

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "market_ticks:EUR/USD")
      # Start periodic staleness check
      :timer.send_interval(10_000, self(), :check_stale_data)
      # Defer heavy loading to after mount
      send(self(), :load_initial_data)
    end

    socket =
      socket
      |> assign(:page_title, "Treasury Intelligence")
      |> assign(:current_path, "/dashboard")
      |> assign(:market_timeframe, "1D")
      |> assign(:cash_flow_timeframe, "30D")
      |> assign(:stale_data, false)
      |> assign(:current_pair, "EUR/USD")
      |> assign(:current_price, "1.0854")
      |> assign(:last_tick_at, DateTime.utc_now())
      |> assign(:initial_chart_data, [])
      |> assign(:market_ticks, [])
      |> assign(:risk_summary, %{total_exposure: "€0.0", at_risk: "€0.0"})
      |> assign(:exposure_heatmap, %{currencies: [], subsidiaries: [], data: %{}})
      |> assign(:payment_matching, %{matched: 0, partial: 0, unmatched: 0})
      |> assign(:recent_activity, [])
      |> assign(:show_step_up, false)
      |> assign(:pending_transfer, nil)
      |> assign(:transfer_threshold, 1_000_000)
      |> assign(:host, get_host(socket))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6 w-full px-4 md:px-6 pb-12">
      <.live_component
        module={NexusWeb.Tenant.Components.StepUpModal}
        id="step-up-modal"
        show={@show_step_up}
        action_id={@pending_transfer && @pending_transfer.transfer_id}
        current_user={@current_user}
        host={@host}
      />

      <div class="flex items-center justify-between mb-2">
        <div>
          <h1 class="text-3xl font-serif italic font-bold text-white tracking-tight">
            Institutional Dashboard
          </h1>
          <p class="text-slate-500 text-sm mt-1">Real-time treasury & exposure intelligence</p>
        </div>
        <div class="flex items-center gap-3">
          <div class="flex bg-slate-900/50 border border-white/5 p-1 rounded-xl mr-2">
            <button
              phx-click="update_threshold"
              phx-value-threshold="1000000"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-bold tracking-widest uppercase transition-all",
                if(Decimal.eq?(@transfer_threshold, 1_000_000),
                  do: "bg-indigo-600 text-white shadow-lg shadow-indigo-600/20",
                  else: "text-slate-500 hover:text-slate-300"
                )
              ]}
            >
              Standard
            </button>
            <button
              phx-click="update_threshold"
              phx-value-threshold="50000"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-bold tracking-widest uppercase transition-all",
                if(Decimal.eq?(@transfer_threshold, 50_000),
                  do: "bg-rose-600 text-white shadow-lg shadow-rose-600/20",
                  else: "text-slate-500 hover:text-slate-300"
                )
              ]}
            >
              Strict
            </button>
            <button
              phx-click="update_threshold"
              phx-value-threshold="10000000"
              class={[
                "px-4 py-1.5 rounded-lg text-[10px] font-bold tracking-widest uppercase transition-all",
                if(Decimal.eq?(@transfer_threshold, 10_000_000),
                  do: "bg-emerald-600 text-white shadow-lg shadow-emerald-600/20",
                  else: "text-slate-500 hover:text-slate-300"
                )
              ]}
            >
              Relaxed
            </button>
          </div>

          <button
            phx-click="initiate_transfer"
            class="bg-indigo-600 hover:bg-indigo-500 text-white px-6 py-2.5 rounded-xl font-bold text-sm shadow-xl shadow-indigo-600/10 transition-all active:scale-95 flex items-center gap-2"
          >
            <span class="hero-arrows-right-left w-4 h-4"></span> Transfer Funds
          </button>
        </div>
      </div>

      <%!-- KPI Header Row (Simplified for focus) --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4 md:gap-6 w-full">
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

        <.kpi_card
          title="Successfully Matched"
          value={to_string(@payment_matching.matched)}
          label="Transactions"
          color="emerald"
          progress={94}
        />
        <.kpi_card
          title="Partial Matches"
          value={to_string(@payment_matching.partial)}
          label="Requires Review"
          color="amber"
          progress={4}
        />
        <.kpi_card
          title="Unmatched Alerts"
          value={to_string(@payment_matching.unmatched)}
          label="Anomalies"
          color="rose"
          progress={2}
        />

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

      <%!-- Main Content: Real-time FX & Risk --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2 flex flex-col">
          <.dark_card class="p-0 h-full min-h-[400px] flex flex-col relative overflow-hidden group">
            <div class="flex items-center justify-between p-6 border-b border-white/5">
              <div>
                <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em] mb-2">
                  FX Performance
                </h2>
                <div class="flex items-baseline gap-3">
                  <span class="text-2xl font-mono tracking-tighter text-white">{@current_price}</span>
                  <span class="text-xs font-semibold text-emerald-400 font-mono tracking-tight">
                    +0.12%
                  </span>
                </div>
              </div>
              <div class="flex items-center gap-3">
                <button class="flex items-center gap-1 text-[10px] font-bold text-slate-400 bg-white/5 hover:bg-white/10 px-3 py-1.5 rounded-md transition-all border border-white/5 uppercase tracking-widest">
                  {@current_pair} <span class="hero-chevron-down w-3 h-3"></span>
                </button>
                <.timeframe_selector
                  active={@market_timeframe}
                  options={["1H", "4H", "1D", "1W"]}
                  on_change="set_market_timeframe"
                />
              </div>
            </div>

            <%!-- ECharts Visualization Bridge --%>
            <div
              id="market-chart"
              class="flex-1 w-full"
              phx-update="ignore"
              phx-hook="ECharts"
              data-pair={@current_pair}
              data-initial={Jason.encode!(@initial_chart_data)}
            >
            </div>

            <div class="px-6 py-4 flex justify-between items-center border-t border-white/5 bg-slate-900/40">
              <span class="text-[10px] font-bold text-slate-600 uppercase tracking-widest">
                Source: Real-time Polygon Feed
              </span>
              <div class="flex items-center gap-2">
                <div class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></div>
                <span class="text-[9px] uppercase tracking-widest text-emerald-500 font-black">
                  Live Stream
                </span>
              </div>
            </div>
          </.dark_card>
        </div>

        <div class="lg:col-span-1">
          <.dark_card class="p-6 h-full flex flex-col">
            <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em] mb-6">
              Your Currencies
            </h2>
            <div class="space-y-4">
              <%= for tick <- @market_ticks do %>
                <div class="flex items-center justify-between group cursor-pointer hover:bg-white/5 p-2 -mx-2 rounded-xl transition-all">
                  <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center font-bold text-[10px] text-slate-400 group-hover:text-white transition-colors">
                      {String.slice(tick.name, 0, 3)}
                    </div>
                    <div>
                      <p class="text-xs font-bold text-slate-200">{tick.name}</p>
                      <p class="text-[9px] text-slate-500 uppercase tracking-widest font-bold">
                        Liquidity: High
                      </p>
                    </div>
                  </div>
                  <div class="text-right">
                    <p class="text-xs font-mono font-bold text-white">{tick.price}</p>
                    <p class={[
                      "text-[10px] font-bold mt-1",
                      if(String.starts_with?(tick.change, "+"),
                        do: "text-emerald-500",
                        else: "text-rose-500"
                      )
                    ]}>
                      {tick.change}
                    </p>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="mt-auto pt-8">
              <div class="bg-indigo-600/5 rounded-2xl p-6 border border-indigo-500/10">
                <h3 class="text-[10px] font-black text-indigo-400 uppercase tracking-[0.2em] mb-4">
                  Risk Aggregator
                </h3>
                <div class="space-y-4 font-mono">
                  <div class="flex justify-between items-baseline">
                    <span class="text-[11px] text-slate-400">Net Exposure</span>
                    <span class="text-lg text-white">{@risk_summary.total_exposure}</span>
                  </div>
                  <div class="flex justify-between items-baseline">
                    <span class="text-[11px] text-slate-400">At Risk (VAR)</span>
                    <span class="text-lg text-amber-400">{@risk_summary.at_risk}</span>
                  </div>
                  <div class="h-1 bg-white/5 rounded-full overflow-hidden mt-4">
                    <div class="h-full bg-amber-500 w-[65%]"></div>
                  </div>
                </div>
              </div>
            </div>
          </.dark_card>
        </div>
      </div>

      <%!-- Middle Row: Massive Risk Heatmap (Full Width) --%>
      <div class="grid grid-cols-1 gap-6">
        <.dark_card class="p-4 md:p-6 min-h-[320px]">
          <h2 class="text-[11px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-8">
            Risk Overview (Exposure Map)
          </h2>
          <div class="overflow-x-auto scroll-soft -mx-4 px-4 md:mx-0 md:px-0">
            <div class="matrix-container mb-4 min-w-[700px]">
              <%!-- Headers --%>
              <div class="col-span-1"></div>
              <%= for curr <- @exposure_heatmap.currencies do %>
                <div class="text-center text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                  {curr}
                </div>
              <% end %>

              <%!-- Data Rows --%>
              <%= for sub <- @exposure_heatmap.subsidiaries do %>
                <div class="text-xs font-medium text-slate-400 self-center text-right pr-4">
                  {sub}
                </div>
                <%= for curr <- @exposure_heatmap.currencies do %>
                  <% amount =
                    Map.get(@exposure_heatmap.data, sub, %{}) |> Map.get(curr, Decimal.new(0)) %>
                  <div class={[
                    "rounded-lg h-12 border transition-all cursor-crosshair group relative",
                    get_risk_color(amount)
                  ]}>
                    <div class="absolute inset-x-0 bottom-full mb-2 hidden group-hover:block bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-lg p-2 text-center text-xs shadow-xl z-20 w-32 -ml-8">
                      <div class="font-bold text-white">{format_heatmap_amount(amount, curr)}</div>
                      <div class="text-[10px] text-slate-400 mt-1">{sub} · {curr}</div>
                    </div>
                  </div>
                <% end %>
              <% end %>
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
          </div>
        </.dark_card>
      </div>

      <%!-- Lower Row: Trends & Activity (2/3 & 1/3) --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2 flex flex-col">
          <.dark_card class="p-4 md:p-6 min-h-[300px] h-full flex flex-col relative overflow-hidden group">
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

        <div class="lg:col-span-1 flex flex-col">
          <%!-- Section E: Recent Activity Feed --%>
          <.dark_card class="p-4 md:p-6 h-full">
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

              <%= for item <- @recent_activity do %>
                <.activity_item
                  icon={item.icon}
                  color={item.color}
                  title={item.title}
                  subtitle={item.subtitle}
                  time_ago={item.time}
                />
              <% end %>

              <%= if Enum.empty?(@recent_activity) do %>
                <div class="flex flex-col items-center justify-center h-32 opacity-30">
                  <span class="hero-inbox w-8 h-8 mb-2"></span>
                  <p class="text-[10px] uppercase tracking-widest font-bold">No Recent Activity</p>
                </div>
              <% end %>

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
  def handle_info(:load_initial_data, socket) do
    org_id = socket.assigns.current_user.org_id

    # Fetch initial seed data from TimescaleDB
    initial_chart_data = Treasury.list_recent_ohlc("EUR/USD")

    # Fetch latest price from cache with fallback
    current_price =
      case PriceCache.get_price("EUR/USD") do
        {:ok, price} -> price
        _ -> "1.0854"
      end

    # Fetch policy
    policy = Treasury.get_treasury_policy(org_id)
    threshold = (policy && policy.transfer_threshold) || Decimal.new(1_000_000)

    socket =
      socket
      |> assign(:current_price, current_price)
      |> assign(:initial_chart_data, initial_chart_data)
      |> assign(:market_ticks, Treasury.list_active_currencies())
      |> assign(:risk_summary, Treasury.get_risk_summary(org_id))
      |> assign(:exposure_heatmap, Treasury.list_exposure_heatmap(org_id))
      |> assign(:payment_matching, ERP.get_payment_matching_stats(org_id))
      |> assign(:recent_activity, ERP.list_recent_activity(org_id))
      |> assign(:transfer_threshold, threshold)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:market_tick, pair, price, timestamp}, socket) do
    if pair == socket.assigns.current_pair do
      # Push the new tick to ECharts hook
      socket =
        socket
        |> assign(:current_price, price)
        |> assign(:last_tick_at, timestamp)
        |> assign(:stale_data, false)
        |> push_event("new-tick", %{
          pair: pair,
          price: price,
          time: DateTime.to_iso8601(timestamp)
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:check_stale_data, socket) do
    # Mark data as stale if it's older than 60 seconds
    diff = DateTime.diff(DateTime.utc_now(), socket.assigns.last_tick_at)
    {:noreply, assign(socket, :stale_data, diff > 60)}
  end

  @impl true
  def handle_info({:step_up_success, _action_id}, socket) do
    # Biometric verified! Now we can commit the pending action.
    Process.send_after(self(), :finalize_transfer, 1000)
    {:noreply, assign(socket, show_step_up: false)}
  end

  @impl true
  def handle_info(:close_step_up, socket) do
    {:noreply, assign(socket, show_step_up: false, pending_transfer: nil)}
  end

  @impl true
  def handle_info(:finalize_transfer, socket) do
    # Mocking the successful finalization after step-up
    {:noreply,
     socket
     |> put_flash(:info, "Identity Verified. High-value transfer authorized.")
     |> assign(:recent_activity, ERP.list_recent_activity(socket.assigns.current_user.org_id))
     |> assign(:pending_transfer, nil)}
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("biometric_reset", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("biometric_login", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_threshold", %{"threshold" => threshold}, socket) do
    threshold = Decimal.new(threshold)
    org_id = socket.assigns.current_user.org_id

    case Treasury.update_transfer_threshold(org_id, threshold) do
      :ok ->
        {:noreply, assign(socket, :transfer_threshold, threshold)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update threshold: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("set_market_timeframe", %{"tf" => tf}, socket) do
    {:noreply, assign(socket, :market_timeframe, tf)}
  end

  @impl true
  def handle_event("initiate_transfer", _params, socket) do
    # For demo: Attempt a High-Value transfer that triggers Step-Up
    transfer_id = "TX-#{Base.encode32(:crypto.strong_rand_bytes(5), padding: false)}"

    command = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: transfer_id,
      org_id: socket.assigns.current_user.org_id,
      user_id: socket.assigns.current_user.id,
      from_currency: "EUR",
      to_currency: "USD",
      # €5M -> High Value
      amount: "5000000",
      threshold: socket.assigns.transfer_threshold
    }

    case Nexus.App.dispatch(command) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer initiated successfully.")
         |> assign(:recent_activity, ERP.list_recent_activity(socket.assigns.current_user.org_id))}

      {:error, :step_up_required} ->
        {:noreply, assign(socket, show_step_up: true, pending_transfer: command)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Transfer failed: #{inspect(reason)}")}
    end
  end

  def handle_event("set_cash_flow_timeframe", %{"tf" => tf}, socket) do
    {:noreply, assign(socket, :cash_flow_timeframe, tf)}
  end

  defp get_host(socket) do
    if connected?(socket) do
      get_connect_info(socket, :uri).host
    else
      socket.endpoint.host()
    end
  end

  defp get_risk_color(amount) do
    cond do
      Decimal.gt?(amount, 1_000_000) ->
        "bg-rose-500/70 border-rose-500/40 shadow-[0_0_15px_-3px_rgba(244,63,94,0.3)] hover:bg-rose-400 hover:-translate-y-1 hover:shadow-[0_8px_25px_-4px_rgba(244,63,94,0.5)]"

      Decimal.gt?(amount, 500_000) ->
        "bg-amber-500/50 border-amber-500/20 shadow-[0_0_15px_-3px_rgba(245,158,11,0.3)] hover:bg-amber-400 hover:-translate-y-1 hover:shadow-[0_8px_25px_-4px_rgba(245,158,11,0.5)]"

      Decimal.gt?(amount, 0) ->
        "bg-indigo-500/20 border-indigo-500/10 hover:bg-indigo-500/30 hover:border-indigo-400/30 hover:-translate-y-1 hover:shadow-[0_4px_20px_-4px_rgba(99,102,241,0.3)]"

      true ->
        "bg-white/5 border-white/5 opacity-20"
    end
  end

  defp format_heatmap_amount(amount, currency) do
    symbol =
      case currency do
        "EUR" -> "€"
        "USD" -> "$"
        "GBP" -> "£"
        "JPY" -> "¥"
        "CHF" -> "₣"
        _ -> ""
      end

    formatted =
      cond do
        Decimal.gt?(amount, 1_000_000) ->
          "#{Decimal.div(amount, 1_000_000) |> Decimal.round(1)}M"

        Decimal.gt?(amount, 1_000) ->
          "#{Decimal.div(amount, 1_000) |> Decimal.round(0)}K"

        true ->
          to_string(Decimal.round(amount, 0))
      end

    "#{symbol}#{formatted}"
  end
end
