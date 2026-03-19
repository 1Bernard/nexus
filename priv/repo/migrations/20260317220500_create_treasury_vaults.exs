defmodule Nexus.Repo.Migrations.CreateTreasuryVaults do
  use Ecto.Migration

  def change do
    create table(:treasury_vaults, primary_key: false) do
      add :id, :string, primary_key: true
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :bank_name, :string, null: false
      add :account_number, :string
      add :iban, :string
      add :currency, :string, null: false
      add :balance, :decimal, precision: 20, scale: 2, default: 0
      add :provider, :string, null: false
      add :status, :string, default: "active"

      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_vaults, [:org_id])
    create index(:treasury_vaults, [:currency])
  end
end
