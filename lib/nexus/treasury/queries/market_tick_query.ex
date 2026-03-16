defmodule Nexus.Treasury.Queries.MarketTickQuery do
  @moduledoc """
  Composable queries for the treasury_market_ticks projection.
  Provides filters for pairs, time ranges, and sorting.
  """
  import Ecto.Query

  alias Nexus.Treasury.Projections.MarketTick

  @doc "Base query for all MarketTick operations."
  @spec base() :: Ecto.Query.t()
  def base, do: from(m in MarketTick)

  @doc "Filters ticks by currency pair (e.g. 'EUR/USD')."
  @spec for_pair(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def for_pair(query, pair) do
    where(query, [m], m.pair == ^pair)
  end

  @doc "Sorts ticks by time, newest first."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [m], desc: m.tick_time)
  end

  @doc "Limits the number of ticks returned."
  @spec recent(Ecto.Query.t(), integer()) :: Ecto.Query.t()
  def recent(query, limit \\ 1000) do
    limit(query, ^limit)
  end
end
