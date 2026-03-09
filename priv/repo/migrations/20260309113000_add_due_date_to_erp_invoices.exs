defmodule Nexus.Repo.Migrations.AddDueDateToErpInvoices do
  use Ecto.Migration

  def change do
    alter table(:erp_invoices) do
      add :due_date, :utc_datetime
    end

    create index(:erp_invoices, [:due_date])
  end
end
