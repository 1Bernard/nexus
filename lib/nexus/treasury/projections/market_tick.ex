defmodule Nexus.Treasury.Projections.MarketTick do
  @moduledoc """
  Schema for each individual FX market tick, stored in the treasury_market_ticks
  TimescaleDB hypertable for time-series analysis. No tenant isolation — ticks
  are global market data, not org-specific.
  """
  use Nexus.Schema

  schema "treasury_market_ticks" do
    field :pair, :string
    field :price, :decimal
    field :tick_time, :utc_datetime_usec

    timestamps()
  end

  def changeset(market_tick, attrs) do
    market_tick
    |> cast(attrs, [:pair, :price, :tick_time])
    |> validate_required([:pair, :price, :tick_time])
  end
end
