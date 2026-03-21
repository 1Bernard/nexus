defmodule Nexus.Treasury.Queries.ReconciliationQuery do
  @moduledoc """
  Composable queries for the treasury_reconciliations table.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for Reconciliation with Tenant enrichment, scoped by organization."
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    query =
      if org_id == :all do
        Reconciliation
      else
        from(reconciliation in Reconciliation, where: reconciliation.org_id == ^org_id)
      end

    from(reconciliation in query,
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

  @doc "High-level builder for listing reconciliations, scoped by organization."
  @spec list_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def list_query(org_id) do
    base(org_id)
    |> newest_first()
  end

  @doc "Sorts reconciliations by match date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [reconciliation], desc: reconciliation.matched_at)
  end

  @doc "High-level builder for reconciliation statistics, scoped by organization."
  @spec stats_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def stats_query(org_id) do
    simple_base(org_id)
  end

  @doc "Simple base query without joins, scoped by organization."
  @spec simple_base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def simple_base(:all), do: Reconciliation
  def simple_base(org_id) do
    from(reconciliation in Reconciliation, where: reconciliation.org_id == ^org_id)
  end
end
