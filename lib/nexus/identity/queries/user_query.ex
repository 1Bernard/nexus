defmodule Nexus.Identity.Queries.UserQuery do
  @moduledoc """
  Read-model queries for User Management and RBAC.
  Optimized for high-density DataGrids with cursor pagination.
  """
  import Ecto.Query
  alias Nexus.Identity.Projections.User
  alias Nexus.Repo

  @doc """
  Lists users within an organization with support for search, role filtering, and pagination.
  """
  def list_users_by_org(org_id, params \\ %{}) do
    query = from(u in User, where: u.org_id == ^org_id)

    query
    |> filter_by_search(params["search"])
    |> filter_by_role(params["role"])
    |> paginate(params["after"], params["limit"] || 20)
    |> Repo.all()
  end

  @doc """
  Returns the total count of users in an organization.
  """
  def total_users_count(org_id) do
    from(u in User, where: u.org_id == ^org_id)
    |> Repo.aggregate(:count, :id)
  end

  # --- Internal Helpers ---

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_term = "%#{search}%"

    from(u in query,
      where: ilike(u.display_name, ^search_term) or ilike(u.email, ^search_term)
    )
  end

  defp filter_by_role(query, nil), do: query
  defp filter_by_role(query, "all"), do: query

  defp filter_by_role(query, role) do
    from(u in query, where: u.role == ^role)
  end

  defp paginate(query, nil, limit) do
    from(u in query,
      order_by: [asc: u.created_at, asc: u.id],
      limit: ^limit
    )
  end

  defp paginate(query, after_id, limit) do
    # Simple keyset pagination based on ID (assuming UUID/v7 or consistent ordering)
    # In a real production system, we'd use a combination of inserted_at + ID for stable sorting.
    from(u in query,
      where: u.id > ^after_id,
      order_by: [asc: u.created_at, asc: u.id],
      limit: ^limit
    )
  end
end
