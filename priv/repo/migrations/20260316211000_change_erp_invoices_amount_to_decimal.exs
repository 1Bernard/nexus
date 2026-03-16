defmodule Nexus.Repo.Migrations.ChangeErpInvoicesAmountToDecimal do
  use Ecto.Migration

  def up do
    # 1. Add temporary decimal column
    alter table(:erp_invoices) do
      add :amount_dec, :decimal, precision: 20, scale: 4
    end

    flush()

    # 2. Convert string to decimal
    execute "UPDATE erp_invoices SET amount_dec = amount::decimal"

    # 3. Drop old string column
    alter table(:erp_invoices) do
      remove :amount
    end

    flush()

    # 4. Rename new column to amount
    rename table(:erp_invoices), :amount_dec, to: :amount

    # 4. Same for line_items totals if they exist in the JSONB (Line items are just maps, we keep them as is for now but update documentation)
  end

  def down do
    alter table(:erp_invoices) do
      add :amount_str, :string
    end

    execute "UPDATE erp_invoices SET amount_str = amount::text"

    alter table(:erp_invoices) do
      remove :amount
    end

    rename table(:erp_invoices), :amount_str, to: :amount
  end
end
