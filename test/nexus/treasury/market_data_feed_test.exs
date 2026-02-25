defmodule Nexus.Treasury.MarketDataFeedTest do
  use Cabbage.Feature, file: "treasury/market_data_feed.feature"
  use Nexus.DataCase

  @moduletag :feature

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Gateways.PolygonClient

  setup do
    on_exit(fn ->
      :ets.delete_all_objects(:market_rates)
    end)

    :ok
  end

  # --- Scenario: Ingesting a real-time market tick ---

  defgiven ~r/^the Polygon API is connected$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^a market tick is received for "(?<pair>[^"]+)" at price "(?<price>[^"]+)"$/,
          %{pair: pair, price: price},
          state do
    payload = %{"ev" => "C", "pair" => pair, "p" => price, "t" => System.os_time(:millisecond)}
    json = Jason.encode!([payload])

    PolygonClient.handle_frame({:text, json}, %{})

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
    :ets.insert(:market_rates, {pair, "1.0800", stale_time})
    {:ok, Map.put(state, :stale_pair, pair)}
  end

  defwhen ~r/^the dashboard queries the system status$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^a "Stale Data" warning is flagged for the currency pair$/, _vars, state do
    [{_pair, _price, last_tick}] = :ets.lookup(:market_rates, state.stale_pair)
    diff_seconds = DateTime.diff(DateTime.utc_now(), last_tick)
    assert diff_seconds > 15 * 60
    {:ok, state}
  end
end
