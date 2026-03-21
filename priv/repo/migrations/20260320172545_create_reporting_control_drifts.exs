defmodule Nexus.Repo.Migrations.CreateReportingControlDrifts do
  use Ecto.Migration

  def change do
    create table(:reporting_control_drifts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :control_key, :string, null: false
      add :original_value, :text
      add :current_value, :text
      add :drift_score, :decimal, default: 0
      add :last_changed_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create index(:reporting_control_drifts, [:org_id])
    create unique_index(:reporting_control_drifts, [:org_id, :control_key])
  end
end
