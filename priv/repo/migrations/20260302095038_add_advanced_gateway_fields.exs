defmodule Nexus.Repo.Migrations.AddAdvancedGatewayFields do
  use Ecto.Migration

  def change do
    alter table(:erp_statements) do
      add :matched_count, :integer, default: 0
      add :overlap_warning, :boolean, default: false
    end

    alter table(:erp_statement_lines) do
      add :error_message, :text
    end
  end
end
