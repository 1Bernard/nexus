defmodule Nexus.Repo.Migrations.RenameProcessedTransfersTimestamp do
  use Ecto.Migration

  def change do
    rename table(:bulk_payment_processed_transfers), :inserted_at, to: :created_at
  end
end
