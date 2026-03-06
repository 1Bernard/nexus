defmodule Nexus.Repo.Migrations.CreatePaymentsBulkPayments do
  use Ecto.Migration

  def change do
    create table(:payments_bulk_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :status, :string, null: false
      add :total_items, :integer, null: false
      add :processed_items, :integer, default: 0
      add :total_amount, :decimal, precision: 20, scale: 4, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:payments_bulk_payments, [:org_id])
  end
end
