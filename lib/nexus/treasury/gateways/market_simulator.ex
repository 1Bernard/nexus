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
    # Seed base prices as Decimals
    prices = %{
      "EUR/USD" => Decimal.new("1.0854"),
      "GBP/USD" => Decimal.new("1.2642"),
      "USD/JPY" => Decimal.new("150.12")
    }

    schedule_tick()
    {:ok, %{prices: prices}}
  end

  @impl true
  def handle_info(:tick, state) do
    # Pick a random pair to update
    pair = Enum.random(@pairs)
    old_price = Map.get(state.prices, pair)

    # Generate a realistic fluctuation (0.01% - 0.05%) using Decimal
    # fluctuation_factor = 1 + (random_value * 0.0005 * direction)
    direction = if :rand.uniform() > 0.5, do: 1, else: -1
    random_factor = :rand.uniform() |> Decimal.from_float() |> Decimal.mult(Decimal.new("0.0005")) |> Decimal.mult(Decimal.new(direction))

    # new_price = old_price * (1 + random_factor)
    new_price = Decimal.mult(old_price, Decimal.add(Decimal.new(1), random_factor)) |> Decimal.round(4)

    # Smart Yielding: Only skip if a LIVE tick was received within the last 5 seconds.
    case PriceCache.get_last_tick(pair) do
      {:ok, {_any_price, %DateTime{} = at, :live}} ->
        if DateTime.diff(Nexus.Schema.utc_now(), at) > 5 do
          process_simulated_tick(pair, new_price)
        else
          Logger.info(
            "[Treasury] [SIMULATOR] Yielding to live feed for #{pair} (Last live tick #{DateTime.diff(Nexus.Schema.utc_now(), at)}s ago)"
          )
        end

      _ ->
        process_simulated_tick(pair, new_price)
    end

    new_state = put_in(state.prices[pair], new_price)
    schedule_tick()

    {:noreply, new_state}
  end

  defp process_simulated_tick(pair, %Decimal{} = decimal_price) do
    timestamp = Nexus.Schema.utc_now()
    # Format for UI/Logging
    formatted_price = Decimal.to_string(decimal_price, :normal)

    # 1. Update ETS cache with :simulated source
    PriceCache.update_price(pair, formatted_price, :simulated)

    # 2. Dispatch command via App (Dispatcher) with eventual consistency
    # Market ticks don't require ACID guarantees across the whole platform for every single 2s update.
    cmd = %RecordMarketTick{
      pair: pair,
      # Use Decimal struct for domain
      price: decimal_price,
      timestamp: timestamp
    }

    case Nexus.App.dispatch(cmd, consistency: :eventual) do
      :ok ->
        Logger.info(
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
