defmodule Nexus.Repo.Migrations.CreateTreasuryActionableIntelligenceTables do
  use Ecto.Migration

  def change do
    create table(:treasury_policy_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :currency_pair, :string, null: false
      add :exposure_amount, :decimal, precision: 20, scale: 4, null: false
      add :threshold, :decimal, precision: 20, scale: 4, null: false
      add :triggered_at, :utc_datetime_usec, null: false

      timestamps(inserted_at: :created_at)
    end

    create index(:treasury_policy_alerts, [:org_id])
    create index(:treasury_policy_alerts, [:triggered_at])

    create table(:treasury_forecasts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :currency, :string, size: 3, null: false
      add :horizon_days, :integer, null: false
      add :predicted_inflow, :decimal, precision: 20, scale: 4, null: false
      add :predicted_outflow, :decimal, precision: 20, scale: 4, null: false
      add :predicted_gap, :decimal, precision: 20, scale: 4, null: false
      add :generated_at, :utc_datetime_usec, null: false

      timestamps(inserted_at: :created_at)
    end

    create index(:treasury_forecasts, [:org_id])
    create unique_index(:treasury_forecasts, [:org_id, :currency, :horizon_days])
  end
end
