defmodule Nexus.Treasury.Projectors.MarketTickProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.MarketTickProjector"

  alias Nexus.Treasury.Events.MarketTickRecorded
  alias Nexus.Treasury.Projections.MarketTick

  project(%MarketTickRecorded{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :market_tick, %MarketTick{
      pair: event.pair,
      price: event.price,
      tick_time: event.timestamp
    })
  end)
end
