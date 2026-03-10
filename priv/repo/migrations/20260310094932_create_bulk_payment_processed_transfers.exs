defmodule Nexus.Repo.Migrations.CreateBulkPaymentProcessedTransfers do
  use Ecto.Migration

  def change do
    create table(:bulk_payment_processed_transfers, primary_key: false) do
      add :bulk_payment_id, :binary_id, primary_key: true
      add :transfer_id, :binary_id, primary_key: true

      timestamps(updated_at: false)
    end
  end
end
