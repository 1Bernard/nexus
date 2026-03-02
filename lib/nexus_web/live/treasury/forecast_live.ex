defmodule NexusWeb.Treasury.ForecastLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury
  alias Nexus.Treasury.Projections.ForecastSnapshot

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

    {:ok,
     socket
     |> assign(:page_title, "Liquidity Forecasting")
     |> assign(:org_id, org_id)
     |> assign(:currency, currency)
     |> assign(:horizon_days, horizon_days)
     |> assign(:forecast, forecast)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("generate_forecast", _params, socket) do
    org_id = socket.assigns.org_id
    currency = socket.assigns.currency
    horizon_days = socket.assigns.horizon_days

    case Treasury.generate_forecast(org_id, currency, horizon_days) do
      :ok ->
        # In a real app, we'd wait for the projection. For this demo, we'll refresh after a short delay
        # or rely on the user to see the "Processing" state.
        Process.send_after(self(), :refresh_forecast, 2000)
        {:noreply, assign(socket, :loading, true)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate forecast: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(:refresh_forecast, socket) do
    forecast = Treasury.get_latest_forecast(socket.assigns.org_id, socket.assigns.currency)
    {:noreply, socket |> assign(:forecast, forecast) |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex justify-between items-end">
        <div>
          <h1 class="text-3xl font-bold text-slate-100">Liquidity Forecasting</h1>
          <p class="text-slate-400 mt-1">
            Predictive cash flow analysis using Scholastic Linear Regression.
          </p>
        </div>
        <div class="flex gap-3">
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
            <div class="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-5 backdrop-blur-sm">
              <h3 class="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">
                Insight Summary
              </h3>
              <div class="space-y-4">
                <% last_point = List.last(@forecast.data_points) %>
                <div>
                  <label class="block text-xs text-slate-500 mb-1">Target End Gap</label>
                  <div class={"text-xl font-bold #{if last_point["predicted_amount"] >= 0, do: "text-emerald-400", else: "text-rose-400"}"}>
                    €{:erlang.float_to_binary(last_point["predicted_amount"] * 1.0, decimals: 2)}
                  </div>
                </div>
                <p class="text-xs text-slate-500 leading-relaxed">
                  Based on historical volatility and pending commitments, the liquidity position is expected to {if last_point[
                                                                                                                      "predicted_amount"
                                                                                                                    ] >=
                                                                                                                      0,
                                                                                                                    do:
                                                                                                                      "strengthen",
                                                                                                                    else:
                                                                                                                      "weaken"} over the next period.
                </p>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Chart Area -->
        <div class="lg:col-span-3">
          <div class="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl relative overflow-hidden min-h-[500px]">
            <div class="absolute top-0 right-0 p-4">
              <div class="flex items-center gap-4 text-[10px] font-bold uppercase tracking-widest text-slate-600">
                <div class="flex items-center gap-1.5">
                  <div class="w-2 h-2 rounded-full bg-slate-600"></div>
                  HISTORICAL
                </div>
                <div class="flex items-center gap-1.5">
                  <div class="w-2 h-2 rounded-full bg-indigo-500"></div>
                  PREDICTED
                </div>
              </div>
            </div>

            <%= if @forecast do %>
              <div
                id="forecast-chart"
                phx-hook="ForecastChart"
                data-points={Jason.encode!(@forecast.data_points)}
                class="w-full h-[440px]"
              >
              </div>
            <% else %>
              <div class="flex flex-col items-center justify-center h-[440px] text-slate-600">
                <span class="hero-chart-bar-square w-16 h-16 mb-4 opacity-20"></span>
                <p>No forecast data available for this selection.</p>
                <p class="text-sm">Click "Regenerate Forecast" to run the engine.</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
