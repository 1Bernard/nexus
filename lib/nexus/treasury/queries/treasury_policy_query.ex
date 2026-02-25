defmodule Nexus.Treasury.Queries.TreasuryPolicyQuery do
  @moduledoc """
  Query builder for Treasury Policies.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.TreasuryPolicy

  def base, do: TreasuryPolicy

  def for_org(query \\ base(), org_id) do
    from(p in query, where: p.org_id == ^org_id)
  end
end
