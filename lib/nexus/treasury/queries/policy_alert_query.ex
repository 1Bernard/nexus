defmodule Nexus.Treasury.Queries.PolicyAlertQuery do
  @moduledoc """
  Query builder for policy alerts.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.PolicyAlert

  def base, do: PolicyAlert

  def for_org(query, org_id) do
    from(a in query, where: a.org_id == ^org_id)
  end

  def recent(query, limit \\ 5) do
    from(a in query, order_by: [desc: a.triggered_at], limit: ^limit)
  end
end
