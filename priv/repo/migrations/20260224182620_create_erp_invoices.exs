defmodule Nexus.Repo.Migrations.CreateErpInvoices do
  use Ecto.Migration

  def change do
    create table(:erp_invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :entity_id, :string, null: false
      add :currency, :string, null: false
      add :amount, :string, null: false
      add :subsidiary, :string
      add :line_items, {:array, :map}, default: []
      add :sap_document_number, :string, null: false
      add :status, :string, null: false, default: "ingested"

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:erp_invoices, [:org_id])
    create unique_index(:erp_invoices, [:sap_document_number])
  end
end
