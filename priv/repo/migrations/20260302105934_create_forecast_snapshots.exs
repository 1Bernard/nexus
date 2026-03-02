defmodule Nexus.Repo.Migrations.CreateForecastSnapshots do
  use Ecto.Migration

  def change do
    create table(:treasury_forecast_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :currency, :string, null: false
      add :horizon_days, :integer, null: false
      add :data_points, {:array, :map}, null: false
      add :generated_at, :naive_datetime, null: false

      timestamps(updated_at: false, inserted_at: :created_at)
    end

    create index(:treasury_forecast_snapshots, [:org_id, :currency])
  end
end
