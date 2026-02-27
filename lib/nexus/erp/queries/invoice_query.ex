defmodule Nexus.ERP.Queries.InvoiceQuery do
  @moduledoc """
  Composable queries for the erp_invoices projection.
  """
  import Ecto.Query
  alias Nexus.ERP.Projections.Invoice

  def base, do: from(i in Invoice)

  def for_org(query, org_id) do
    where(query, [i], i.org_id == ^org_id)
  end

  def with_status(query, status) do
    where(query, [i], i.status == ^status)
  end

  def with_currency(query, currency) do
    where(query, [i], i.currency == ^currency)
  end

  def for_subsidiary(query, subsidiary) do
    where(query, [i], i.subsidiary == ^subsidiary)
  end

  def sum_amount(query) do
    select(query, [i], fragment("sum(CAST(? AS decimal))", i.amount))
  end

  def count(query) do
    select(query, [i], count(i.id))
  end

  def newest_first(query) do
    order_by(query, [i], desc: i.created_at)
  end

  def limit_results(query, limit) do
    limit(query, ^limit)
  end
end
