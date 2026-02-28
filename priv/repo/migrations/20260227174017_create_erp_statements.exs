defmodule Nexus.Repo.Migrations.CreateErpStatements do
  use Ecto.Migration

  def change do
    create table(:erp_statements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :filename, :string, null: false
      add :format, :string, null: false
      add :status, :string, null: false, default: "uploaded"
      add :line_count, :integer, null: false, default: 0
      add :uploaded_at, :utc_datetime_usec

      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:erp_statements, [:org_id])
    create index(:erp_statements, [:org_id, :uploaded_at])

    create table(:erp_statement_lines, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :statement_id, references(:erp_statements, type: :binary_id, on_delete: :delete_all),
        null: false

      add :org_id, :binary_id, null: false
      add :date, :string
      add :ref, :string
      add :amount, :decimal, precision: 20, scale: 6
      add :currency, :string, size: 3
      add :narrative, :text

      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:erp_statement_lines, [:statement_id])
    create index(:erp_statement_lines, [:org_id])
  end
end
