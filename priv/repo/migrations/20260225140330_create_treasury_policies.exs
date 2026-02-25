defmodule Nexus.Repo.Migrations.CreateTreasuryPolicies do
  use Ecto.Migration

  def change do
    create table(:treasury_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :transfer_threshold, :decimal, precision: 20, scale: 2, default: 1_000_000.00

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:treasury_policies, [:org_id])
  end
end
