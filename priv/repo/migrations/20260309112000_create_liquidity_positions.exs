defmodule Nexus.Repo.Migrations.CreateLiquidityPositions do
  use Ecto.Migration

  def change do
    create table(:treasury_liquidity_positions, primary_key: false) do
      add :id, :string, primary_key: true
      add :org_id, :binary_id, null: false
      add :currency, :string, null: false
      add :amount, :decimal, null: false, default: 0

      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_liquidity_positions, [:org_id])
    create unique_index(:treasury_liquidity_positions, [:org_id, :currency])
  end
end
