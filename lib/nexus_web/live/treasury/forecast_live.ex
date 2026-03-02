defmodule NexusWeb.Treasury.ForecastLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to forecast events if needed, but for now we'll just poll or refresh
    end

    org_id = socket.assigns.current_user.org_id
    # Default
    currency = "EUR"
    horizon_days = 30

    forecast = Treasury.get_latest_forecast(org_id, currency)
    historical_data = Treasury.list_historical_cash_flow(org_id, currency)

    # Restore horizon from latest forecast if available
    horizon_days = if forecast, do: forecast.horizon_days, else: 30

    {:ok,
     socket
     |> assign(:page_title, "Liquidity Forecasting")
     |> assign(:org_id, org_id)
     |> assign(:currency, currency)
     |> assign(:horizon_days, horizon_days)
     |> assign(:forecast, forecast)
     |> assign(:historical_data, historical_data)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("generate_forecast", _params, socket) do
    org_id = socket.assigns.org_id
    currency = socket.assigns.currency
    horizon_days = socket.assigns.horizon_days

    case Treasury.generate_forecast(org_id, currency, horizon_days) do
      :ok ->
        Process.send_after(self(), :refresh_forecast, 2000)
        {:noreply, assign(socket, :loading, true)}

      {:error, :insufficient_data} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(
           :error,
           "Insufficient historical data. Ensure at least 60 days of ERP statements are imported to generate a reliable predictive model."
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Analysis failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("set_horizon", %{"days" => days}, socket) do
    days = String.to_integer(days)
    # Update horizon and trigger auto-regeneration
    socket = assign(socket, :horizon_days, days)
    handle_event("generate_forecast", %{}, socket)
  end

  @impl true
  def handle_event("download_csv", _params, socket) do
    csv_data = Treasury.list_forecast_csv(socket.assigns.org_id, socket.assigns.currency)
    filename = "nexus_forecast_#{socket.assigns.currency}_#{socket.assigns.horizon_days}d.csv"

    {:noreply,
     push_event(socket, "phx:download-file", %{
       filename: filename,
       content: csv_data,
       type: "text/csv"
     })}
  end

  @impl true
  def handle_info(:refresh_forecast, socket) do
    forecast = Treasury.get_latest_forecast(socket.assigns.org_id, socket.assigns.currency)

    historical_data =
      Treasury.list_historical_cash_flow(socket.assigns.org_id, socket.assigns.currency)

    {:noreply,
     socket
     |> assign(:forecast, forecast)
     |> assign(:historical_data, historical_data)
     |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex justify-between items-end">
        <div>
          <h1 class="text-3xl font-bold text-slate-100 italic tracking-tight">Cash Flow Outlook</h1>
          <p class="text-slate-400 mt-1 uppercase text-[10px] tracking-widest font-semibold flex items-center gap-2">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
            Predictive Model: Scholar Linear Regression
          </p>
        </div>
        <div class="flex gap-3">
          <button
            phx-click="download_csv"
            class="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg font-medium transition-all flex items-center gap-2 border border-slate-700"
          >
            <span class="hero-arrow-down-tray w-4 h-4"></span> Export CSV
          </button>
          <button
            phx-click="generate_forecast"
            disabled={@loading}
            class="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-medium transition-all flex items-center gap-2 disabled:opacity-50"
          >
            <span class="hero-sparkles w-4 h-4"></span>
            {if @loading, do: "Analyzing...", else: "Regenerate Forecast"}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <!-- Stats Sidebar -->
        <div class="lg:col-span-1 space-y-6">
          <div class="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-5 backdrop-blur-sm">
            <h3 class="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">
              Configuration
            </h3>
            <div class="space-y-4">
              <div>
                <label class="block text-xs text-slate-500 mb-1">Base Currency</label>
                <div class="text-slate-200 font-medium">EUR (Euro)</div>
              </div>
              <div>
                <label class="block text-xs text-slate-500 mb-1">Horizon</label>
                <div class="text-slate-200 font-medium">{@horizon_days} Days</div>
              </div>
              <div>
                <label class="block text-xs text-slate-500 mb-1">Engine</label>
                <div class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-indigo-500/10 text-indigo-400 text-[10px] font-bold border border-indigo-500/20">
                  SCHOLAR REGRESSION
                </div>
              </div>
            </div>
          </div>

          <%= if @forecast do %>
            <% last_point = List.last(@forecast.data_points) %>
            <% amt =
              case Float.parse(to_string(last_point["predicted_amount"])) do
                {v, _} -> v
                :error -> 0.0
              end %>

            <div class="space-y-4">
              <div class="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-5 backdrop-blur-sm">
                <h3 class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-4">
                  Projection Summary
                </h3>
                <div class="space-y-3">
                  <div>
                    <label class="block text-[10px] font-bold text-slate-600 uppercase tracking-tighter mb-1">
                      Target Balance
                    </label>
                    <div class={"text-2xl font-mono font-black #{if amt >= 0, do: "text-emerald-400", else: "text-rose-400"}"}>
                      €{if amt < 0, do: "-", else: ""}{:erlang.float_to_binary(abs(amt) * 1.0,
                        decimals: 2
                      )}
                    </div>
                  </div>
                  <p class="text-[11px] text-slate-400 leading-relaxed font-medium">
                    The model predicts a net {if amt >= 0, do: "surplus", else: "shortfall"} by the end of the
                    <span class="text-indigo-400">{@horizon_days}-day</span>
                    outlook.
                  </p>
                  <div class="pt-3 border-t border-slate-700/50 flex items-center justify-between">
                    <span class="text-[10px] font-bold text-slate-500 uppercase">
                      Reliability Index
                    </span>
                    <span class="text-[10px] font-bold text-emerald-500/80 uppercase tracking-widest">
                      95% CI High
                    </span>
                  </div>
                </div>
              </div>

              <%= if Enum.any?(@forecast.data_points, fn p -> (case Float.parse(to_string(p["predicted_amount"])), do: ({v, _} -> v; :error -> 0.0)) < 0 end) do %>
                <div class="flex items-start gap-3 p-4 bg-rose-500/10 rounded-xl border border-rose-500/20 animate-pulse">
                  <div class="p-1.5 bg-rose-500/20 rounded-lg shrink-0">
                    <span class="hero-exclamation-triangle w-4 h-4 text-rose-400"></span>
                  </div>
                  <div class="space-y-1">
                    <h3 class="text-[10px] font-black text-rose-400 uppercase tracking-tighter italic">
                      Liquidity Alert
                    </h3>
                    <p class="text-[10px] text-rose-200/60 leading-tight font-medium">
                      A potential cash shortfall has been detected. Reviewing upcoming payables is recommended.
                    </p>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Chart Area -->
        <div class="lg:col-span-3 space-y-4">
          <div class="flex items-center justify-between">
            <div class="flex bg-slate-800/80 p-1 rounded-xl border border-slate-700/50">
              <%= for days <- [7, 14, 30] do %>
                <button
                  phx-click="set_horizon"
                  phx-value-days={days}
                  class={"px-4 py-1.5 text-xs font-bold rounded-lg transition-all #{if @horizon_days == days, do: "bg-indigo-600 text-white shadow-lg", else: "text-slate-400 hover:text-slate-200"}"}
                >
                  {days}D
                </button>
              <% end %>
            </div>

            <div class="flex items-center gap-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">
              <div class="flex items-center gap-1.5">
                <div class="w-3 h-0.5 bg-slate-500"></div>
                HISTORICAL
              </div>
              <div class="flex items-center gap-1.5">
                <div class="w-3 h-0.5 border-t border-dashed border-indigo-500"></div>
                PREDICTED (95% CI)
              </div>
            </div>
          </div>

          <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl relative overflow-hidden min-h-[500px]">
            <%= if @forecast do %>
              <div
                id="forecast-chart"
                phx-hook="ForecastChart"
                phx-update="ignore"
                data-historical={Jason.encode!(@historical_data)}
                data-points={Jason.encode!(@forecast.data_points)}
                class="w-full h-[440px]"
              >
              </div>
            <% else %>
              <div class="flex flex-col items-center justify-center h-[440px] text-slate-600">
                <span class="hero-chart-bar-square w-16 h-16 mb-4 opacity-20 hidden md:block"></span>
                <p class="text-slate-400 font-medium">Awaiting Initial Model Generation</p>
                <p class="text-sm mt-1 max-w-sm text-center px-4">
                  Run the "Regenerate Forecast" action to fit the Scholar Linear Regression model against your historical cash flow data.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
