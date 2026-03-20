defmodule Nexus.ERP.Queries.InvoiceQuery do
  @moduledoc """
  Composable queries for the erp_invoices projection.
  """
  import Ecto.Query
  alias Nexus.ERP.Projections.Invoice

  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for Invoice, scoped by organization."
  @spec base(Nexus.Types.org_id()) :: Ecto.Query.t()
  def base(org_id) do
    from(i in Invoice, where: i.org_id == ^org_id)
  end

  @doc "Enriches invoice query with Tenant information."
  @spec with_tenant(Ecto.Query.t()) :: Ecto.Query.t()
  def with_tenant(query) do
    from(i in query,
      left_join: t in Tenant,
      on: i.org_id == t.org_id,
      select: %{i | org_name: t.name}
    )
  end

  @doc "Filters invoices by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [i], i.org_id == ^org_id)
  end

  @doc "High-level builder for listing unmatched invoices."
  @spec unmatched_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def unmatched_query(org_id) do
    base(org_id)
    |> with_tenant()
    |> with_status("ingested")
    |> newest_first()
  end

  @doc "High-level builder for listing all invoices for an organization."
  @spec activity_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def activity_query(org_id) do
    base(org_id)
    |> with_tenant()
    |> newest_first()
  end

  @doc "Filters invoices by status."
  @spec with_status(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def with_status(query, status) do
    where(query, [i], i.status == ^status)
  end

  @doc "Filters invoices by currency."
  @spec with_currency(Ecto.Query.t(), Nexus.Types.currency()) :: Ecto.Query.t()
  def with_currency(query, currency) do
    where(query, [i], i.currency == ^currency)
  end

  @doc "Filters invoices by subsidiary."
  @spec for_subsidiary(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def for_subsidiary(query, subsidiary) do
    where(query, [i], i.subsidiary == ^subsidiary)
  end

  @doc "Sums the invoice amounts."
  @spec sum_amount(Ecto.Query.t()) :: Ecto.Query.t()
  def sum_amount(query) do
    select(query, [i], fragment("sum(CAST(? AS decimal))", i.amount))
  end

  @doc "Counts the number of invoices."
  @spec count(Ecto.Query.t()) :: Ecto.Query.t()
  def count(query) do
    select(query, [i], count(i.id))
  end

  @doc "Sorts invoices by creation date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [i], desc: i.created_at)
  end

  @doc "Limits the query results."
  @spec limit_results(Ecto.Query.t(), integer()) :: Ecto.Query.t()
  def limit_results(query, limit) do
    limit(query, ^limit)
  end
end
