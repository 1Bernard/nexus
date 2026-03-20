defmodule Nexus.Repo.Migrations.AddOrgIdToBulkPaymentProcessedTransfers do
  use Ecto.Migration

  def change do
    alter table(:bulk_payment_processed_transfers) do
      add :org_id, :binary_id
    end
  end
end
