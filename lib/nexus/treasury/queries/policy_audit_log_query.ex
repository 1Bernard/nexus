defmodule Nexus.Treasury.Queries.PolicyAuditLogQuery do
  @moduledoc """
  Composable queries for the treasury_policy_audit_logs table.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.PolicyAuditLog
  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for PolicyAuditLog with Tenant enrichment."
  @spec base() :: Ecto.Query.t()
  def base do
    from(log in PolicyAuditLog,
      left_join: t in Tenant,
      on: log.org_id == t.org_id,
      select: %{log | org_name: t.name}
    )
  end

  @doc "Filters policy audit logs by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query
  def for_org(query, org_id) do
    where(query, [log], log.org_id == ^org_id)
  end

  @doc "High-level builder for listing policy audit logs for an organization."
  @spec list_for_org(Nexus.Types.org_id()) :: Ecto.Query.t()
  def list_for_org(org_id) do
    base()
    |> for_org(org_id)
    |> newest_first()
  end

  @doc "Sorts policy audit logs by most recent first."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [log], desc: log.changed_at)
  end
end
