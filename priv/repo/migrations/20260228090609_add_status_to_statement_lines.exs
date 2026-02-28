defmodule Nexus.Repo.Migrations.AddStatusToStatementLines do
  use Ecto.Migration

  def change do
    alter table(:erp_statement_lines) do
      add :status, :string, default: "unmatched", null: false
    end

    create index(:erp_statement_lines, [:status])
    create index(:erp_statement_lines, [:org_id, :status])
  end
end
