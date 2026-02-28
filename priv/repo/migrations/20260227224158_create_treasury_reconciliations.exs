defmodule Nexus.Repo.Migrations.CreateTreasuryReconciliations do
  use Ecto.Migration

  def change do
    create table(:treasury_reconciliations, primary_key: false) do
      add :reconciliation_id, :string, primary_key: true
      add :org_id, :string, null: false
      add :invoice_id, :string, null: false
      add :statement_id, :string, null: false
      add :statement_line_id, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, null: false
      add :status, :string, null: false
      add :matched_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:treasury_reconciliations, [:org_id])
    create unique_index(:treasury_reconciliations, [:invoice_id])
    create unique_index(:treasury_reconciliations, [:statement_line_id])
  end
end
