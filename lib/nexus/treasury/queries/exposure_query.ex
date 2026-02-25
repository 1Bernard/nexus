defmodule Nexus.Treasury.Queries.ExposureQuery do
  @moduledoc """
  Composable queries for treasury_exposure_snapshots.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.ExposureSnapshot

  def base, do: from(e in ExposureSnapshot)

  def for_org(query, org_id) do
    where(query, [e], e.org_id == ^org_id)
  end

  def sum_exposure(query) do
    select(query, [e], sum(e.exposure_amount))
  end
end
