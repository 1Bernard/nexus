defmodule Nexus.Reporting.Queries.ControlMetricQuery do
  @moduledoc """
  Composable queries for the reporting_control_metrics table.
  """
  import Ecto.Query
  alias Nexus.Reporting.Projections.ControlMetric

  @doc "Base query for ControlMetric."
  @spec base() :: Ecto.Query.t()
  def base, do: from(metric in ControlMetric)

  @doc "Builds a query for the compliance scorecard of an organization."
  @spec scorecard_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def scorecard_query(org_id) do
    base()
    |> for_org(org_id)
  end

  @doc "Filters control metrics by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, org_id) do
    where(query, [metric], metric.org_id == ^org_id)
  end
end
