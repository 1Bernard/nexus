defmodule Nexus.Treasury.Queries.ReconciliationQuery do
  @moduledoc """
  Composable queries for the treasury_reconciliations table.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for Reconciliation with Tenant enrichment."
  @spec base() :: Ecto.Query.t()
  def base do
    from(reconciliation in Reconciliation,
      left_join: t in Tenant,
      on: reconciliation.org_id == t.org_id,
      select: %{reconciliation | org_name: t.name}
    )
  end

  @doc "Filters reconciliations by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query
  def for_org(query, org_id) do
    where(query, [reconciliation], reconciliation.org_id == ^org_id)
  end

  @doc "High-level builder for listing reconciliations."
  @spec list_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def list_query(org_id) do
    base()
    |> for_org(org_id)
    |> newest_first()
  end

  @doc "Sorts reconciliations by match date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [reconciliation], desc: reconciliation.matched_at)
  end

  @doc "High-level builder for reconciliation statistics."
  @spec stats_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def stats_query(org_id) do
    simple_base()
    |> for_org(org_id)
  end

  @doc "Simple base query without joins."
  @spec simple_base() :: Ecto.Query.t()
  def simple_base, do: from(reconciliation in Reconciliation)
end
