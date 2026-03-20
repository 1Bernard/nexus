defmodule Nexus.Repo.Migrations.HardenTreasurySchemasV4 do
  use Ecto.Migration

  def up do
    # 1. treasury_liquidity_positions
    drop_if_exists table(:treasury_liquidity_positions)

    create table(:treasury_liquidity_positions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :currency, :string, null: false
      add :amount, :decimal, null: false, default: 0
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_liquidity_positions, [:org_id])
    create unique_index(:treasury_liquidity_positions, [:org_id, :currency])

    # 2. treasury_reconciliations
    drop_if_exists table(:treasury_reconciliations)

    create table(:treasury_reconciliations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :invoice_id, :uuid, null: false
      add :statement_id, :uuid, null: false
      add :statement_line_id, :uuid, null: false
      add :amount, :decimal, null: false
      add :variance, :decimal
      add :variance_reason, :string
      add :actor_email, :string
      add :currency, :string, null: false
      add :status, :string, null: false
      add :matched_at, :utc_datetime_usec
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_reconciliations, [:org_id])
    create unique_index(:treasury_reconciliations, [:invoice_id])
    create unique_index(:treasury_reconciliations, [:statement_line_id])

    # 3. treasury_vaults
    drop_if_exists table(:treasury_vaults)

    create table(:treasury_vaults, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :name, :string, null: false
      add :bank_name, :string, null: false
      add :account_number, :string
      add :iban, :string
      add :currency, :string, null: false
      add :balance, :decimal, precision: 20, scale: 2, default: 0
      add :provider, :string, null: false
      add :status, :string, default: "active"
      add :daily_withdrawal_limit, :decimal, default: 0
      add :requires_multi_sig, :boolean, default: false
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_vaults, [:org_id])
    create index(:treasury_vaults, [:currency])

    # 4. treasury_transfers
    drop_if_exists table(:treasury_transfers)

    create table(:treasury_transfers, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :user_id, :uuid, null: false
      add :from_currency, :string, null: false
      add :to_currency, :string
      add :source_vault_id, :uuid
      add :destination_vault_id, :uuid
      add :amount, :decimal, precision: 20, scale: 2, null: false
      add :status, :string, null: false
      add :type, :string, null: false
      add :recipient_data, :map
      add :executed_at, :utc_datetime_usec
      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_transfers, [:org_id])
    create index(:treasury_transfers, [:user_id])
    create index(:treasury_transfers, [:status])
  end

  def down do
  end
end
