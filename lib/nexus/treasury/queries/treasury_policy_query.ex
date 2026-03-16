defmodule Nexus.Treasury.Queries.TreasuryPolicyQuery do
  @moduledoc """
  Query builder for Treasury Policies.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.TreasuryPolicy

  @doc "Base query for TreasuryPolicy."
  @spec base() :: Ecto.Query.t()
  def base, do: from(p in TreasuryPolicy)

  @doc "Filters policies by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query \\ base(), org_id)
  def for_org(query, :all), do: query
  def for_org(query, org_id) do
    where(query, [p], p.org_id == ^org_id)
  end
end
