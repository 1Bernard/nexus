defmodule Nexus.Reporting.Queries.AuditLogQuery do
  @moduledoc """
  Composable queries for the reporting_audit_logs table.
  """
  import Ecto.Query
  alias Nexus.Reporting.Projections.AuditLog

  @doc "Base query for AuditLog, scoped by organization."
  @spec base(Nexus.Types.org_id()) :: Ecto.Query.t()
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    from(log in AuditLog, where: log.org_id == ^org_id)
  end

  @doc "Filters audit logs by correlation ID."
  @spec for_correlation(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def for_correlation(query, correlation_id) do
    where(query, [log], log.correlation_id == ^correlation_id)
  end

  @doc "Filters audit logs by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [log], log.org_id == ^org_id)
  end

  @doc "Sorts audit logs by most recent first."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [log], desc: log.recorded_at)
  end

  @doc "Sorts audit logs by oldest first."
  @spec oldest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def oldest_first(query) do
    order_by(query, [log], asc: log.recorded_at)
  end

  @doc "Builds a query for the complete event lineage of a correlation ID, scoped by organization."
  @spec lineage_query(Nexus.Types.org_id(), String.t()) :: Ecto.Query.t()
  def lineage_query(org_id, correlation_id) do
    base(org_id)
    |> for_correlation(correlation_id)
    |> oldest_first()
  end

  @doc "Builds a query for the most recent audit logs for an organization."
  @spec newest_for_org_query(Nexus.Types.org_id(), integer()) :: Ecto.Query.t()
  def newest_for_org_query(org_id, limit \\ 50) do
    base(org_id)
    |> newest_first()
    |> limit(^limit)
  end
end
