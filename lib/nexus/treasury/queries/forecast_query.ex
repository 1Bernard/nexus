defmodule Nexus.Treasury.Queries.ForecastQuery do
  @moduledoc """
  Query builder for liquidity forecasts.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.ForecastSnapshot

  def base, do: ForecastSnapshot

  def for_org(query, org_id) do
    from(f in query, where: f.org_id == ^org_id)
  end

  def for_currency(query, currency) do
    from(f in query, where: f.currency == ^currency)
  end

  def newest_first(query) do
    from(f in query, order_by: [desc: f.generated_at, desc: f.created_at])
  end
end
