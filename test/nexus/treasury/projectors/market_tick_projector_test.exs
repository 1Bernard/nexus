defmodule Nexus.Treasury.MarketTickProjectorTest do
  @moduledoc """
  Elite BDD tests for Market Tick Ingestion.
  """
  use Cabbage.Feature, async: false, file: "treasury/market_tick_ingestion.feature"
  use Nexus.DataCase

  alias Nexus.Treasury.Projectors.MarketTickProjector
  alias Nexus.Treasury.Events.MarketTickRecorded
  alias Nexus.Treasury.Projections.MarketTick
  alias Nexus.Repo
  import Ecto.Query

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(MarketTick)
    end)
    :ok
  end

  # --- Given ---

  defgiven ~r/^a market tick for "(?<pair>[^"]+)" at "(?<price>[^"]+)" is recorded$/,
           %{pair: pair, price: price},
           _state do
    event = %MarketTickRecorded{
      pair: pair,
      price: price,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, %{event: event}}
  end

  # --- When ---

  defwhen "the market tick projector handles the event", _args, %{event: event} do
    metadata = %{event_number: 1, handler_name: "Treasury.MarketTickProjector"}

    unboxed_run(fn ->
      assert :ok = MarketTickProjector.handle(event, metadata)
    end)

    :ok
  end

  # --- Then ---

  defthen ~r/^the projected price for "(?<pair>[^"]+)" should be "(?<price>[^"]+)"$/,
          %{pair: pair, price: price},
          _state do
    unboxed_run(fn ->
      tick = Repo.one(from t in MarketTick, where: t.pair == ^pair)
      assert tick != nil
      assert Decimal.equal?(tick.price, Decimal.new(price))
    end)
    :ok
  end

  defthen "the tick ID should be a valid UUIDv7", _args, _state do
    unboxed_run(fn ->
      tick = Repo.one(from t in MarketTick, limit: 1)
      assert tick.id != nil
      assert {:ok, _} = Ecto.UUID.cast(tick.id)
    end)
    :ok
  end
end
