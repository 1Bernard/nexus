defmodule Nexus.Repo.Migrations.CreateReportingControlMetrics do
  use Ecto.Migration

  def change do
    create table(:reporting_control_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :metric_key, :string, null: false
      add :score, :decimal, precision: 5, scale: 2, default: 0.0
      add :metadata, :map, default: %{}

      timestamps(inserted_at: :created_at)
    end

    create unique_index(:reporting_control_metrics, [:org_id, :metric_key])
  end
end
