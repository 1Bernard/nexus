defmodule Nexus.Repo.Migrations.RemoveUniqueIndexFromControlMetrics do
  use Ecto.Migration

  def change do
    drop unique_index(:reporting_control_metrics, [:org_id, :metric_key])
    create index(:reporting_control_metrics, [:org_id, :metric_key, :created_at])
  end
end
