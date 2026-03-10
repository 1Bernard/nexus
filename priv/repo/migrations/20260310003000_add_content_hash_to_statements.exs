defmodule Nexus.Repo.Migrations.AddContentHashToStatements do
  use Ecto.Migration

  def change do
    alter table(:erp_statements) do
      add :content_hash, :string
    end

    create unique_index(:erp_statements, [:org_id, :content_hash])
  end
end
