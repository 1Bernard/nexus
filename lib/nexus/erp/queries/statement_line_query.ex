defmodule Nexus.ERP.Queries.StatementLineQuery do
  @moduledoc """
  Composable queries for the erp_statement_lines projection.
  """
  import Ecto.Query
  alias Nexus.ERP.Projections.StatementLine
  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for StatementLine."
  @spec base() :: Ecto.Query.t()
  def base, do: from(line in StatementLine)

  @doc "Enriches statement line query with Tenant information."
  @spec with_tenant(Ecto.Query.t()) :: Ecto.Query.t()
  def with_tenant(query) do
    from(line in query,
      left_join: t in Tenant,
      on: line.org_id == t.org_id,
      select: %{line | org_name: t.name}
    )
  end

  @doc "High-level builder for listing unmatched statement lines."
  @spec unmatched_query(Nexus.Types.org_id()) :: Ecto.Query.t()
  def unmatched_query(org_id) do
    base()
    |> with_tenant()
    |> for_org(org_id)
    |> with_status("unmatched")
    |> newest_first()
  end

  @doc "Filters statement lines by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query
  def for_org(query, org_id) do
    where(query, [line], line.org_id == ^org_id)
  end

  @doc "Filters statement lines by status."
  @spec with_status(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def with_status(query, status) do
    where(query, [line], line.status == ^status)
  end

  @doc "Filters statement lines by currency."
  @spec with_currency(Ecto.Query.t(), Nexus.Types.currency()) :: Ecto.Query.t()
  def with_currency(query, currency) do
    where(query, [line], line.currency == ^currency)
  end

  @doc "Sorts statement lines by creation date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [line], desc: line.created_at)
  end

  @doc "Sorts statement lines by creation date (oldest first)."
  @spec oldest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def oldest_first(query) do
    order_by(query, [line], asc: line.created_at)
  end

  @doc "Filters statement lines by date range."
  @spec for_date_range(Ecto.Query.t(), String.t(), String.t()) :: Ecto.Query.t()
  def for_date_range(query, start_dt, end_dt) do
    where(query, [line], line.date >= ^start_dt and line.date <= ^end_dt)
  end

  @doc "High-level builder for listing lines of a specific statement."
  @spec for_statement_query(Nexus.Types.binary_id()) :: Ecto.Query.t()
  def for_statement_query(statement_id) do
    base()
    |> for_statement(statement_id)
  end

  @doc "Filters statement lines by statement ID."
  @spec for_statement(Ecto.Query.t(), Nexus.Types.binary_id()) :: Ecto.Query.t()
  def for_statement(query, statement_id) do
    where(query, [line], line.statement_id == ^statement_id)
  end

  @doc "High-level builder for historical cash flow data."
  @spec historical_cash_flow_query(Nexus.Types.org_id(), Nexus.Types.currency(), String.t(), String.t()) :: Ecto.Query.t()
  def historical_cash_flow_query(org_id, currency, start_dt, end_dt) do
    base()
    |> for_org(org_id)
    |> with_currency(currency)
    |> for_date_range(start_dt, end_dt)
    |> historical_cash_flow()
  end

  @doc "Aggregates statement lines for historical cash flow analysis."
  @spec historical_cash_flow(Ecto.Query.t()) :: Ecto.Query.t()
  def historical_cash_flow(query) do
    query
    |> group_by([line], line.date)
    |> select([line], %{date: line.date, amount: sum(line.amount)})
    |> order_by([line], asc: line.date)
  end

  @doc "Counts the number of statement lines."
  @spec count(Ecto.Query.t()) :: Ecto.Query.t()
  def count(query) do
    select(query, [line], count(line.id))
  end
end
