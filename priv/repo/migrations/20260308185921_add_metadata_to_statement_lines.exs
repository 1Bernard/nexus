defmodule Nexus.Repo.Migrations.AddMetadataToStatementLines do
  use Ecto.Migration

  def change do
    alter table(:erp_statement_lines) do
      add :metadata, :map, default: "{}"
    end
  end
end
