defmodule Nexus.ERP.Queries.StatementQuery do
  @moduledoc """
  Composable queries for the erp_statements projection.
  """
  import Ecto.Query
  alias Nexus.ERP.Projections.Statement
  alias Nexus.Organization.Projections.Tenant

  @doc "Base query for Statement."
  @spec base() :: Ecto.Query.t()
  def base, do: from(s in Statement)

  @doc "Enriches statement query with Tenant information."
  @spec with_tenant(Ecto.Query.t()) :: Ecto.Query.t()
  def with_tenant(query) do
    from(s in query,
      left_join: t in Tenant,
      on: s.org_id == t.org_id,
      select: %{s | org_name: t.name}
    )
  end

  @doc "Filters statements by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, org_id) do
    where(query, [s], s.org_id == ^org_id)
  end

  @doc "Sorts statements by upload date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [s], desc: s.uploaded_at)
  end

  @doc "Filters statements by filename (fuzzy match)."
  @spec filter_by_filename(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def filter_by_filename(query, ""), do: query
  def filter_by_filename(query, filename) do
    where(query, [s], ilike(s.filename, ^"%#{filename}%"))
  end

  @doc "Filters statements by upload date string (fuzzy match)."
  @spec filter_by_date(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def filter_by_date(query, ""), do: query
  def filter_by_date(query, date) do
    where(query, [s], fragment("?::text", s.uploaded_at) |> ilike(^"#{date}%"))
  end

  @doc "Filters statements by ID."
  @spec by_id(Ecto.Query.t(), Nexus.Types.binary_id()) :: Ecto.Query.t()
  def by_id(query, id) do
    where(query, [s], s.id == ^id)
  end

  @doc "High-level builder for listing statements with filters."
  @spec list_query(Nexus.Types.org_id(), String.t(), String.t()) :: Ecto.Query.t()
  def list_query(org_id, filename \\ "", date \\ "") do
    base()
    |> with_tenant()
    |> for_org(org_id)
    |> newest_first()
    |> filter_by_filename(filename)
    |> filter_by_date(date)
  end

  @doc "High-level builder for fetching statement content."
  @spec content_query(Nexus.Types.binary_id()) :: Ecto.Query.t()
  def content_query(id) do
    base()
    |> by_id(id)
    |> select_raw_content()
  end

  @doc "Filters statements by content hash."
  @spec with_hash(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def with_hash(query, hash) do
    where(query, [s], s.content_hash == ^hash)
  end

  @doc "Filters statements by exact filename."
  @spec with_filename(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def with_filename(query, filename) do
    where(query, [s], s.filename == ^filename)
  end

  @doc "Counts the number of statements."
  @spec count(Ecto.Query.t()) :: Ecto.Query.t()
  def count(query) do
    select(query, [s], count(s.id))
  end

  @doc "Selects only the raw content field."
  @spec select_raw_content(Ecto.Query.t()) :: Ecto.Query.t()
  def select_raw_content(query) do
    select(query, [s], s.raw_content)
  end
end
