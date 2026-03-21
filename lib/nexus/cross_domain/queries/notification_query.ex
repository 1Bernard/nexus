defmodule Nexus.CrossDomain.Queries.NotificationQuery do
  @moduledoc """
  Composable queries for the cross_domain_notifications table.
  """
  import Ecto.Query
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Organization.Projections.Tenant
  alias Nexus.Identity.Projections.User

  @doc "Base query for Notification, scoped by organization."
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    if org_id == :all do
      Notification
    else
      from(n in Notification, where: n.org_id == ^org_id)
    end
  end

  @doc "Enriches notification query with Tenant and User information."
  @spec with_context(Ecto.Query.t()) :: Ecto.Query.t()
  def with_context(query) do
    from(n in query,
      left_join: t in Tenant,
      on: n.org_id == t.org_id,
      left_join: u in User,
      on: n.user_id == u.id,
      select: %{n | org_name: t.name, user_name: u.display_name}
    )
  end

  @doc "Filters notifications by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [n], n.org_id == ^org_id)
  end

  @doc "Filters notifications by user ID."
  @spec for_user(Ecto.Query.t(), Nexus.Types.binary_id()) :: Ecto.Query.t()
  def for_user(query, user_id) do
    where(query, [n], n.user_id == ^user_id)
  end

  @doc "Sorts notifications by creation date (recent first)."
  @spec newest_first(Ecto.Query.t()) :: Ecto.Query.t()
  def newest_first(query) do
    order_by(query, [n], desc: n.created_at)
  end

  @doc "Limits the query results."
  @spec limit_results(Ecto.Query.t(), integer()) :: Ecto.Query.t()
  def limit_results(query, limit) do
    limit(query, ^limit)
  end
end
