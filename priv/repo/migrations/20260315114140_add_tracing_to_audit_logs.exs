defmodule Nexus.Repo.Migrations.AddTracingToAuditLogs do
  use Ecto.Migration

  def change do
    alter table(:reporting_audit_logs) do
      add :correlation_id, :binary_id
      add :causation_id, :binary_id
    end
  end
end
