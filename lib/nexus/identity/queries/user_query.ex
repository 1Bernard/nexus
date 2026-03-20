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
  @spec list_users_by_org(Nexus.Types.org_id(), map()) :: [User.t()]
  def list_users_by_org(:all, params) do
    list_all_users(params)
  end

  def list_users_by_org(org_id, params) do
    from(u in User,
      left_join: t in Nexus.Organization.Projections.Tenant,
      on: u.org_id == t.org_id,
      where: u.org_id == ^org_id,
      select: %{u | org_name: t.name}
    )
    |> list_users_query(params)
  end

  @doc """
  Lists ALL users on the platform (System Admin only).
  """
  @spec list_all_users(map()) :: [User.t()]
  def list_all_users(params \\ %{}) do
    from(u in User,
      left_join: t in Nexus.Organization.Projections.Tenant,
      on: u.org_id == t.org_id,
      select: %{u | org_name: t.name}
    )
    |> list_users_query(params)
  end

  defp list_users_query(base_query, params) do
    base_query
    |> filter_by_search(params["search"])
    |> filter_by_role(params["role"])
    |> paginate(params["cursor_after"], params["limit"] || 20)
    |> Repo.all()
  end

  @doc """
  Fetches a single user by their unique ID, scoped by organization.
  """
  @spec get_user(Nexus.Types.org_id(), Nexus.Types.user_id()) :: User.t() | nil
  def get_user(org_id, id) do
    from(u in User, where: u.org_id == ^org_id and u.id == ^id)
    |> Repo.one()
  end

  @doc """
  Internal system fetch by ID (unscoped by org).
  ONLY use this in authentication hooks where org_id is not yet known.
  """
  @spec get_user_system(Nexus.Types.user_id()) :: User.t() | nil
  def get_user_system(id), do: Repo.get(User, id)

  @doc """
  Returns the total count of users in an organization.
  """
  @spec total_users_count(Nexus.Types.org_id()) :: integer()
  def total_users_count(:all), do: total_users_count()

  def total_users_count(org_id) do
    from(u in User, where: u.org_id == ^org_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the total count of all users on the platform.
  """
  @spec total_users_count() :: integer()
  def total_users_count do
    Repo.aggregate(User, :count, :id)
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
