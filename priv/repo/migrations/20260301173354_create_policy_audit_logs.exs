defmodule Nexus.Repo.Migrations.CreatePolicyAuditLogs do
  use Ecto.Migration

  def change do
    create table(:treasury_policy_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :actor_email, :string, null: false
      add :mode, :string, null: false
      add :threshold, :decimal, null: false
      add :changed_at, :utc_datetime_usec, null: false

      timestamps(inserted_at: :created_at, type: :utc_datetime_usec)
    end

    create index(:treasury_policy_audit_logs, [:org_id])
  end
end
