defmodule Nexus.Treasury.Gateways.MarketSimulator do
  @moduledoc """
  Simulates FX market ticks when the live feed is unavailable.
  Ensures the Institutional Dashboard remains dynamic for demos.
  """
  use GenServer
  require Logger

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Commands.RecordMarketTick

  @pairs ["EUR/USD", "GBP/USD", "USD/JPY"]
  # 2 seconds
  @tick_interval 2000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Treasury] [SIMULATOR] Starting FX Market Simulator...")
    # Seed base prices
    prices = %{
      "EUR/USD" => 1.0854,
      "GBP/USD" => 1.2642,
      "USD/JPY" => 150.12
    }

    schedule_tick()
    {:ok, %{prices: prices}}
  end

  @impl true
  def handle_info(:tick, state) do
    # Pick a random pair to update
    pair = Enum.random(@pairs)
    old_price = Map.get(state.prices, pair)

    # Generate a realistic fluctuation (0.01% - 0.05%)
    change = :rand.uniform() * 0.0005 * if :rand.uniform() > 0.5, do: 1, else: -1
    new_price = old_price * (1 + change)

    process_simulated_tick(pair, new_price)

    new_state = put_in(state.prices[pair], new_price)
    schedule_tick()

    {:noreply, new_state}
  end

  defp process_simulated_tick(pair, price) do
    timestamp = DateTime.utc_now()
    # Ensure price is a Decimal for Ecto/Commanded projections
    decimal_price = Decimal.from_float(price)
    # Format for UI/Logging
    formatted_price = Decimal.to_string(decimal_price, :normal)

    # 1. Update ETS cache
    PriceCache.update_price(pair, formatted_price)

    # 2. Dispatch command via App (Dispatcher)
    cmd = %RecordMarketTick{
      pair: pair,
      # Use Decimal struct for domain
      price: decimal_price,
      timestamp: timestamp
    }

    case Nexus.App.dispatch(cmd) do
      :ok ->
        Logger.debug(
          "[Treasury] [SIMULATOR] Successfully recorded tick for #{pair}: #{formatted_price}"
        )

        Phoenix.PubSub.broadcast(
          Nexus.PubSub,
          "market_ticks:#{pair}",
          {:market_tick, pair, formatted_price, timestamp}
        )

      {:error, reason} ->
        Logger.error(
          "[Treasury] [SIMULATOR] Failed to record tick for #{pair}: #{inspect(reason)}"
        )
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
