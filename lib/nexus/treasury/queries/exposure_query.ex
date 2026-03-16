defmodule Nexus.Treasury.Queries.ExposureQuery do
  @moduledoc """
  Composable queries for treasury_exposure_snapshots.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.ExposureSnapshot

  @doc "Base query for ExposureSnapshot."
  @spec base() :: Ecto.Query.t()
  def base, do: from(e in ExposureSnapshot)

  @doc "Filters exposures by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query
  def for_org(query, org_id) do
    where(query, [e], e.org_id == ^org_id)
  end

  @doc "Calculates the sum of exposure amounts."
  @spec sum_exposure(Ecto.Query.t()) :: Ecto.Query.t()
  def sum_exposure(query) do
    select(query, [e], sum(e.exposure_amount))
  end
end
