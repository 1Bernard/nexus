defmodule Nexus.Treasury.Services.RebalancingEngine do
  @moduledoc """
  Service for calculating the delta between current liquidity and target allocations.
  Delegates predictive calculations to RebalancingMath as per Rule 5.
  """
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.{LiquidityPosition, TreasuryPolicy}
  # No need for manual import of Ecto.Query here since we use Repo directly for now
  # or we can use the query modules.

  @doc """
  Calculates the required rebalancing trades for an organization.
  Returns a list of suggested trades: `%{sell: "USD", buy: "EUR", amount: #Decimal<...>}`
  """
  @spec calculate(Nexus.Types.org_id()) :: [map()]
  def calculate(org_id) do
    with %TreasuryPolicy{} = policy <- get_policy(org_id),
         positions <- list_positions(org_id),
         target_map <- policy.target_allocations,
         true <- map_size(target_map) > 0 do

      Nexus.Treasury.Services.RebalancingMath.calculate_trades(
        positions,
        target_map,
        policy.rebalance_threshold
      )
    else
      _ -> []
    end
  end

  defp get_policy(org_id) do
    Repo.get_by(TreasuryPolicy, org_id: org_id)
  end

  defp list_positions(org_id) do
    import Ecto.Query
    Repo.all(from(p in LiquidityPosition, where: p.org_id == ^org_id))
  end
end
