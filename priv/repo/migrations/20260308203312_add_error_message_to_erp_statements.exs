defmodule Nexus.Repo.Migrations.AddErrorMessageToErpStatements do
  use Ecto.Migration

  def change do
    alter table(:erp_statements) do
      add :error_message, :text
    end
  end
end
