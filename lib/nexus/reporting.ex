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

  @spec get_compliance_scorecard(Types.org_id()) :: [map()]
  def get_compliance_scorecard(org_id) do
    # 1. Fetch persistent metrics
    persisted =
      ControlMetricQuery.scorecard_query(org_id)
      |> Repo.all()

    # 2. Calculate real-time SoD score
    sod_conflicts = list_sod_conflicts(org_id)

    sod_score =
      if Enum.empty?(sod_conflicts), do: 100, else: max(0, 100 - length(sod_conflicts) * 10)

    # 3. Merge real-time scores into the scorecard
    sod_metric = %{metric_key: "sod_cleanliness", score: Decimal.new(sod_score)}

    # Simple merge for now: prefer real-time SoD over persisted
    persisted
    |> Enum.reject(fn m -> m.metric_key == "sod_cleanliness" end)
    |> Kernel.++([sod_metric])
  end

  @doc """
  Returns historical control metrics for trend visualization.
  """
  @spec get_control_drift(Types.org_id(), integer()) :: [map()]
  def get_control_drift(org_id, _days \\ 7) do
    # Fetch historical data points for trend analysis
    # For now, we simulate drift by returning recent daily snapshots
    ControlMetricQuery.scorecard_query(org_id)
    |> Repo.all()
    |> Enum.map(fn m ->
      %{
        metric_key: m.metric_key,
        score: m.score,
        updated_at: m.updated_at
      }
    end)
  end

  @spec list_sod_conflicts(Types.org_id()) :: [map()]
  def list_sod_conflicts(org_id) do
    # Toxic Combinations:
    # 1. Initiate (trader) + Authorize (approver/admin)
    # 2. Initiate (trader) + Policy (admin)
    # 3. Authorize (approver) + Policy (admin)

    from(u in Nexus.Identity.Projections.User,
      where: u.org_id == ^org_id,
      where: fragment("cardinality(?) > 1", u.roles),
      select: u
    )
    |> Repo.all()
    |> Enum.flat_map(fn user ->
      roles = user.roles

      conflicts = []

      conflicts =
        if Enum.member?(roles, "trader") &&
             (Enum.member?(roles, "approver") || Enum.member?(roles, "admin")) do
          [
            %{conflict_type: "Toxic Combination: Initiate + Authorize", severity: "High"}
            | conflicts
          ]
        else
          conflicts
        end

      conflicts =
        if Enum.member?(roles, "trader") && Enum.member?(roles, "admin") do
          [%{conflict_type: "Toxic Combination: Initiate + Policy", severity: "High"} | conflicts]
        else
          conflicts
        end

      conflicts =
        if Enum.member?(roles, "approver") && Enum.member?(roles, "admin") do
          [
            %{conflict_type: "Toxic Combination: Authorize + Policy", severity: "Medium"}
            | conflicts
          ]
        else
          conflicts
        end

      Enum.map(conflicts, fn conflict ->
        Map.merge(conflict, %{
          user_id: user.id,
          email: user.email,
          roles: user.roles
        })
      end)
    end)
  end

  @doc """
  Fetches event lineage with advanced filtering, scoped by organization.
  """
  @spec get_event_lineage(Types.org_id(), map()) :: [
          Nexus.Reporting.Projections.AuditLog.t()
        ]
  def get_event_lineage(org_id, filters \\ %{}) do
    AuditLogQuery.lineage_query(org_id, filters)
    |> Repo.all()
  end

  @doc """
  Generates a subset of audit logs based on sampling criteria.
  """
  @spec generate_audit_sample(Types.org_id(), map()) :: [Nexus.Reporting.Projections.AuditLog.t()]
  def generate_audit_sample(org_id, params) do
    limit = String.to_integer(params["size"] || "10")
    method = params["method"] || "random"

    query = AuditLogQuery.base(org_id)

    query =
      case method do
        "random" ->
          AuditLogQuery.random_sample(query, limit)

        "high_value" ->
          threshold = Decimal.new(params["threshold"] || "100000")

          query
          |> AuditLogQuery.high_value_sample(threshold)
          |> AuditLogQuery.newest_first()
          |> limit(^limit)

        "risk_based" ->
          query
          |> AuditLogQuery.risk_based_sample()
          |> limit(^limit)

        _ ->
          query
          |> AuditLogQuery.newest_first()
          |> limit(^limit)
      end

    Repo.all(query)
  end

  # --- CCM & DRIFT QUERIES ---

  @doc """
  Returns a specific control drift for an organization.
  """
  @spec get_control_drift_by_type(Types.org_id(), String.t(), String.t()) ::
          {:ok, map()} | {:error, :not_found}
  def get_control_drift_by_type(org_id, type, _severity) do
    # For now, we match on control_key (the type in BDD)
    case Repo.get_by(Nexus.Reporting.Projections.ControlDrift, org_id: org_id, control_key: type) do
      nil -> {:error, :not_found}
      drift -> {:ok, drift}
    end
  end

  @doc """
  Lists all remediation escalations for an organization.
  """
  @spec list_remediation_escalations(Types.org_id()) :: {:ok, [map()]}
  def list_remediation_escalations(org_id) do
    # We query the ControlMetric table for 'escalation_integrity' entries
    escalations =
      from(m in Nexus.Reporting.Projections.ControlMetric,
        where: m.org_id == ^org_id,
        where: m.metric_key == "escalation_integrity",
        select: m.metadata
      )
      |> Repo.all()
      |> Enum.map(fn meta ->
        # Map keys are strings when retrieved from JSONB metadata
        action = Map.get(meta, "action") || Map.get(meta, :action, "manual_audit")
        %{type: action, metadata: meta}
      end)

    {:ok, escalations}
  end

  @doc """
  Lists system notifications for a given user.
  Delegates to the CrossDomain context if necessary, but provided here for context unity.
  """
  @spec list_user_notifications(Types.user_id()) :: [map()]
  def list_user_notifications(user_id) do
    from(n in Nexus.CrossDomain.Projections.Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.created_at]
    )
    |> Repo.all()
  end
end
