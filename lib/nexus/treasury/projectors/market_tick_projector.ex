defmodule Nexus.Treasury.Projectors.MarketTickProjector do
  @moduledoc """
  Listens for MarketTickRecorded events and appends each tick to the
  treasury_market_ticks TimescaleDB hypertable for time-series analysis.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.MarketTickProjector"

  alias Nexus.Treasury.Events.MarketTickRecorded
  alias Nexus.Treasury.Projections.MarketTick

  project(%MarketTickRecorded{} = event, _metadata, fn multi ->
    price =
      case event.price do
        p when is_binary(p) -> Decimal.new(p)
        %Decimal{} = p -> p
        p when is_number(p) -> Decimal.from_float(p * 1.0)
        _ -> Decimal.new("0")
      end

    tick_time =
      case event.timestamp do
        t when is_binary(t) ->
          case DateTime.from_iso8601(t) do
            {:ok, dt, _offset} -> dt
            _ -> DateTime.utc_now()
          end

        %DateTime{} = t ->
          t

        _ ->
          DateTime.utc_now()
      end

    Ecto.Multi.insert(multi, :market_tick, %MarketTick{
      pair: event.pair,
      price: price,
      tick_time: tick_time
    })
  end)
end
