defmodule Nexus.Repo.Migrations.AddModeThresholdsToTreasuryPolicies do
  use Ecto.Migration

  def change do
    alter table(:treasury_policies) do
      add :mode_thresholds, :map,
        default: %{"standard" => "1000000", "strict" => "50000", "relaxed" => "10000000"}
    end
  end
end
