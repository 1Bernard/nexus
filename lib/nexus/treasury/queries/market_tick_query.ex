defmodule Nexus.Treasury.Queries.MarketTickQuery do
  @moduledoc """
  Composable queries for the treasury_market_ticks projection.
  Provides filters for pairs, time ranges, and sorting.
  """
  import Ecto.Query

  alias Nexus.Treasury.Projections.MarketTick

  @doc "Base query for all MarketTick operations."
  def base, do: from(m in MarketTick)

  @doc "Filters ticks by currency pair (e.g. 'EUR/USD')."
  def for_pair(query, pair) do
    where(query, [m], m.pair == ^pair)
  end

  @doc "Sorts ticks by time, newest first."
  def newest_first(query) do
    order_by(query, [m], desc: m.tick_time)
  end

  @doc "Limits the number of ticks returned."
  def recent(query, limit \\ 1000) do
    limit(query, ^limit)
  end
end
