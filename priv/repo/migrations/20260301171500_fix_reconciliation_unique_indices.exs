defmodule Nexus.Repo.Migrations.FixReconciliationUniqueIndices do
  use Ecto.Migration

  def up do
    # Remove old strict unique indices
    drop_if_exists index(:treasury_reconciliations, [:invoice_id])
    drop_if_exists index(:treasury_reconciliations, [:statement_line_id])

    # Add partial unique indices that allow re-matching after reversal/rejection
    # Only one 'matched' or 'pending' record allowed per invoice/line
    create unique_index(:treasury_reconciliations, [:invoice_id],
             name: :treasury_reconciliations_active_invoice_index,
             where: "status IN ('matched', 'pending')"
           )

    create unique_index(:treasury_reconciliations, [:statement_line_id],
             name: :treasury_reconciliations_active_line_index,
             where: "status IN ('matched', 'pending')"
           )
  end

  def down do
    drop_if_exists index(:treasury_reconciliations, [],
                     name: :treasury_reconciliations_active_invoice_index
                   )

    drop_if_exists index(:treasury_reconciliations, [],
                     name: :treasury_reconciliations_active_line_index
                   )

    create unique_index(:treasury_reconciliations, [:invoice_id])
    create unique_index(:treasury_reconciliations, [:statement_line_id])
  end
end
