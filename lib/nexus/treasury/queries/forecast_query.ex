defmodule Nexus.Treasury.Queries.ForecastQuery do
  @moduledoc """
  Query builder for liquidity forecasts.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.ForecastSnapshot

  @doc "Base query for ForecastSnapshot, scoped by organization."
  @spec base(Nexus.Types.org_id()) :: Ecto.Query.t()
  def base(org_id) do
    from(f in ForecastSnapshot, where: f.org_id == ^org_id)
  end

  @doc "Filters forecasts by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [f], f.org_id == ^org_id)
  end

  @doc "Filters forecasts by currency."
  @spec for_currency(Ecto.Query.t(), Nexus.Types.currency()) :: Ecto.Query.t()
  def for_currency(query, currency) do
    where(query, [f], f.currency == ^currency)
  end

  @doc "Sorts forecasts by generation and creation dates (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [f], desc: f.generated_at, desc: f.created_at)
  end
end
