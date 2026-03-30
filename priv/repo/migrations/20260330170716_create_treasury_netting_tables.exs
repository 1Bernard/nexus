defmodule Nexus.Repo.Migrations.CreateTreasuryNettingTables do
  use Ecto.Migration

  def change do
    create table(:treasury_netting_cycles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :currency, :string, null: false
      add :status, :string, null: false, default: "active"
      add :total_amount, :decimal, precision: 20, scale: 4, default: 0
      add :period_start, :utc_datetime_usec
      add :period_end, :utc_datetime_usec
      
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_netting_cycles, [:org_id])
    create index(:treasury_netting_cycles, [:status])

    create table(:treasury_netting_entries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :netting_id, references(:treasury_netting_cycles, type: :uuid, on_delete: :delete_all), null: false
      add :invoice_id, :uuid, null: false
      add :subsidiary, :string
      add :amount, :decimal, precision: 20, scale: 4
      add :currency, :string
      
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_netting_entries, [:netting_id])
    create unique_index(:treasury_netting_entries, [:netting_id, :invoice_id])
  end
end
