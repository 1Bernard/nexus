defmodule Nexus.Treasury.Projections.MarketTick do
  @moduledoc """
  Ecto schema modeling the Hypertable of market ticks in TimescaleDB.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
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
