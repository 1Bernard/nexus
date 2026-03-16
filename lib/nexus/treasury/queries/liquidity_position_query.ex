defmodule Nexus.Treasury.Queries.LiquidityPositionQuery do
  @moduledoc """
  Composable queries for the treasury_liquidity_positions table.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.LiquidityPosition

  @doc "Base query for LiquidityPosition."
  @spec base() :: Ecto.Query.t()
  def base, do: from(position in LiquidityPosition)

  @doc "High-level builder for listing liquidity positions by organization."
  @spec for_org_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org_query(org_id) do
    base()
    |> for_org(org_id)
  end

  @doc "Filters liquidity positions by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [position], position.org_id == ^org_id)
  end
end
