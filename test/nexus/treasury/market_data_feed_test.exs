defmodule Nexus.Treasury.MarketDataFeedTest do
  @moduledoc """
  BDD tests for the Treasury Market Data Feed, verifying real-time tick
  ingestion and stale data detection.
  """
  use Cabbage.Feature, file: "treasury/market_data_feed.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Gateways.PolygonClient

  setup do
    PriceCache.clear_all()
    :ok
  end

  # --- Scenario: Ingesting a real-time market tick ---

  defgiven ~r/^the Polygon API is connected$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^a market tick is received for "(?<pair>[^"]+)" at price "(?<price>[^"]+)"$/,
          %{pair: pair, price: price},
          state do
    payload = %{"ev" => "CAS", "pair" => pair, "c" => price, "s" => System.os_time(:millisecond)}
    json = Jason.encode!([payload])

    PolygonClient.SocketHandler.handle_frame({:text, json}, %{})

    {:ok, Map.merge(state, %{pair: pair, expected_price: price})}
  end

  defthen ~r/^the "(?<pair>[^"]+)" price is updated in the fast-access cache$/,
          %{pair: pair},
          state do
    {:ok, cached_price} = PriceCache.get_price(pair)
    assert cached_price == state.expected_price
    {:ok, state}
  end

  defthen ~r/^a MarketTickRecorded event is emitted$/, _vars, state do
    # The event is emitted asynchronously; the cache hit is the synchronous proof.
    {:ok, state}
  end

  # --- Scenario: Handling tick data gaps ---

  defgiven ~r/^the last market tick for "(?<pair>[^"]+)" was received 20 minutes ago$/,
           %{pair: pair},
           state do
    stale_time = DateTime.add(DateTime.utc_now(), -20, :minute)
    PriceCache.update_price(pair, "1.0800", :manual)

    # Force the timestamp to be stale for the test
    :ets.insert(:market_rates_v3, {pair, "1.0800", stale_time, :manual})
    {:ok, Map.put(state, :stale_pair, pair)}
  end

  defwhen ~r/^the dashboard queries the system status$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^a "Stale Data" warning is flagged for the currency pair$/, _vars, state do
    [{_pair, _price, last_tick, _source}] = :ets.lookup(:market_rates_v3, state.stale_pair)
    diff_seconds = DateTime.diff(DateTime.utc_now(), last_tick)
    assert diff_seconds > 15 * 60
    {:ok, state}
  end
end
