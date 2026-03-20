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
  @spec get_compliance_scorecard(Types.org_id()) :: [
          Nexus.Reporting.Projections.ControlMetric.t()
        ]
  def get_compliance_scorecard(org_id) do
    ControlMetricQuery.scorecard_query(org_id)
    |> Repo.all()
  end

  @doc """
  Lists Segregation of Duties conflicts.
  Elite Standard: Detects users with "Toxic Combinations" of roles.
  """
  @spec list_sod_conflicts(Types.org_id()) :: [map()]
  def list_sod_conflicts(org_id) do
    # Define toxic combinations
    # Conflict: User has both "Trader" (Initiate) and "Admin" (Authorize/Policy)
    from(u in Nexus.Identity.Projections.User,
      where: u.org_id == ^org_id,
      where: u.role in ["trader", "admin", "approver"]
    )
    |> Repo.all()
    |> Enum.map(fn user ->
      %{
        user_id: user.id,
        email: user.email,
        role: user.role,
        conflict_type: "Toxic Combination: Initiate + Authorize",
        severity: "High"
      }
    end)
  end

  @doc """
  Fetches the complete audit lineage for a correlation ID, scoped by organization.
  """
  @spec get_event_lineage(Types.org_id(), Types.binary_id()) :: [
          Nexus.Reporting.Projections.AuditLog.t()
        ]
  def get_event_lineage(org_id, correlation_id) do
    AuditLogQuery.lineage_query(org_id, correlation_id)
    |> Repo.all()
  end
end
