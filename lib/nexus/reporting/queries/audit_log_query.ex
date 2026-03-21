defmodule Nexus.Reporting.Queries.AuditLogQuery do
  @moduledoc """
  Composable queries for the reporting_audit_logs table.
  """
  import Ecto.Query
  alias Nexus.Reporting.Projections.AuditLog

  @doc "Base query for AuditLog, scoped by organization."
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    if org_id == :all do
      AuditLog
    else
      from(log in AuditLog, where: log.org_id == ^org_id)
    end
  end

  @doc "Filters audit logs by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [log], log.org_id == ^org_id)
  end

  @doc "Filters audit logs by correlation ID."
  @spec for_correlation(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def for_correlation(query, nil), do: query
  def for_correlation(query, correlation_id) do
    where(query, [log], log.correlation_id == ^correlation_id)
  end

  @doc "Filters audit logs by actor email."
  @spec for_user(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def for_user(query, nil), do: query
  def for_user(query, email) do
    where(query, [log], log.actor_email == ^email)
  end

  @doc "Filters audit logs by event type."
  @spec for_type(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def for_type(query, nil), do: query
  def for_type(query, type) do
    where(query, [log], log.event_type == ^type)
  end

  @doc "Filters audit logs within a time range."
  @spec within_range(Ecto.Query.t(), DateTime.t() | nil, DateTime.t() | nil) :: Ecto.Query.t()
  def within_range(query, nil, nil), do: query
  def within_range(query, start_at, nil) do
    where(query, [log], log.recorded_at >= ^start_at)
  end
  def within_range(query, nil, end_at) do
    where(query, [log], log.recorded_at <= ^end_at)
  end
  def within_range(query, start_at, end_at) do
    where(query, [log], log.recorded_at >= ^start_at and log.recorded_at <= ^end_at)
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

  @doc "Builds a query for event lineage with optional filters."
  @spec lineage_query(Nexus.Types.org_id(), map()) :: Ecto.Query.t()
  def lineage_query(org_id, filters \\ %{}) do
    base(org_id)
    |> for_correlation(Map.get(filters, :correlation_id))
    |> for_user(Map.get(filters, :user_email))
    |> for_type(Map.get(filters, :event_type))
    |> within_range(Map.get(filters, :start_at), Map.get(filters, :end_at))
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
