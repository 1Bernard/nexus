defmodule Nexus.Treasury.Queries.PolicyAlertQuery do
  @moduledoc """
  Query builder for policy alerts.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.PolicyAlert

  @doc "Base query for PolicyAlert."
  @spec base() :: Ecto.Query.t()
  def base, do: from(a in PolicyAlert)

  @doc "Filters alerts by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, org_id) do
    where(query, [a], a.org_id == ^org_id)
  end

  @doc "Sorts alerts by most recent first and limits results."
  @spec recent(Ecto.Query.t(), integer()) :: Ecto.Query.t()
  def recent(query, limit \\ 5) do
    query
    |> order_by([a], desc: a.triggered_at)
    |> limit(^limit)
  end
end
