defmodule Nexus.Repo.Migrations.CreateTreasuryTransfers do
  use Ecto.Migration

  def change do
    create table(:treasury_transfers, primary_key: false) do
      add :id, :string, primary_key: true
      add :org_id, :binary_id, null: false
      add :user_id, :string, null: false
      add :from_currency, :string, null: false
      add :to_currency, :string
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
end
