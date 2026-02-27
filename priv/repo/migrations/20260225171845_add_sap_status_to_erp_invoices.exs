defmodule Nexus.Repo.Migrations.AddSapStatusToErpInvoices do
  use Ecto.Migration

  def change do
    alter table(:erp_invoices) do
      add :sap_status, :string
    end
  end
end
