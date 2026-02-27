defmodule Nexus.Repo.Migrations.AddModeToTreasuryPolicies do
  use Ecto.Migration

  def change do
    alter table(:treasury_policies) do
      add :mode, :string, null: false, default: "standard"
    end
  end
end
