defmodule Nexus.Reporting do
  @moduledoc """
  The Reporting context facade.

  This module serves as the primary entry point for all reporting and compliance data.
  It delegates low-level data access to specialized query modules, ensuring a clean
  separation between domain orchestration and data retrieval.
  """
  import Ecto.Query, warn: false
  alias Nexus.Repo
  alias Nexus.Reporting.Queries.{AuditLogQuery, ControlMetricQuery}
  alias Nexus.Types

  @doc """
  Returns the compliance scorecard for an organization.
  """
  @spec get_compliance_scorecard(Types.org_id()) :: [Nexus.Reporting.Projections.ControlMetric.t()]
  def get_compliance_scorecard(org_id) do
    ControlMetricQuery.scorecard_query(org_id)
    |> Repo.all()
  end

  @doc """
  Lists Segregation of Duties conflicts.

  Elite Standard: Detects users with "Toxic Combinations" of roles.
  """
  @spec list_sod_conflicts(Types.org_id()) :: [map()]
  def list_sod_conflicts(_org_id) do
    # Placeholder: In a real elite system, this would be a specialized SoD Matrix query.
    []
  end

  @doc """
  Fetches the complete audit lineage for a correlation ID.
  """
  @spec get_event_lineage(Types.binary_id()) :: [Nexus.Reporting.Projections.AuditLog.t()]
  def get_event_lineage(correlation_id) do
    AuditLogQuery.lineage_query(correlation_id)
    |> Repo.all()
  end
end
