defmodule Nexus.Treasury.Queries.TreasuryPolicyQuery do
  @moduledoc """
  Query builder for Treasury Policies.
  """
  import Ecto.Query
  alias Nexus.Treasury.Projections.TreasuryPolicy

  @doc "Base query for TreasuryPolicy, scoped by organization."
  @spec base(Nexus.Types.org_id() | :all) :: Ecto.Query.t()
  def base(org_id) do
    if org_id == :all do
      TreasuryPolicy
    else
      from(p in TreasuryPolicy, where: p.org_id == ^org_id)
    end
  end

  @doc "Filters policies by organization ID."
  @spec for_org(Ecto.Query.t(), Nexus.Types.org_id()) :: Ecto.Query.t()
  def for_org(query, :all), do: query

  def for_org(query, org_id) do
    where(query, [p], p.org_id == ^org_id)
  end
end
