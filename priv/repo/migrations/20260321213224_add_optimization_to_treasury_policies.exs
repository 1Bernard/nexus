defmodule Nexus.Repo.Migrations.AddOptimizationToTreasuryPolicies do
  use Ecto.Migration

  def change do
    alter table(:treasury_policies) do
      add :target_allocations, :map, default: %{}
      add :rebalance_threshold, :decimal, precision: 20, scale: 4, default: 0.05
    end
  end
end
