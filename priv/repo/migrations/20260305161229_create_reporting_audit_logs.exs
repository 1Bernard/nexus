defmodule Nexus.Repo.Migrations.CreateReportingAuditLogs do
  use Ecto.Migration

  def change do
    create table(:reporting_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :actor_email, :string, null: false
      add :org_id, :binary_id
      add :tenant_name, :string
      add :details, :map
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:reporting_audit_logs, [:org_id])
    create index(:reporting_audit_logs, [:recorded_at])
  end
end
