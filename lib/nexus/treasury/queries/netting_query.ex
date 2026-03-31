defmodule Nexus.Treasury.Queries.NettingQuery do
  @moduledoc """
  Query builder for Netting read models.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.NettingCycle

  def base(org_id) do
    from(c in NettingCycle, where: c.org_id == ^org_id)
  end

  def get_query(org_id, netting_id) do
    base(org_id)
    |> where([c], c.id == ^netting_id)
  end

  def active_query(org_id) do
    base(org_id)
    |> where([c], c.status == "active")
  end

  def settled_query(org_id) do
    base(org_id)
    |> where([c], c.status == "settled")
  end

  def newest_first(query) do
    order_by(query, [c], desc: c.inserted_at)
  end
end
