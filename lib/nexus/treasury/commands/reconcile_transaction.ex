defmodule Nexus.Treasury.Commands.ReconcileTransaction do
  @moduledoc """
  Command to record a successful match between an invoice and a statement line.
  """
  @derive Jason.Encoder
  defstruct [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_id,
    :statement_line_id,
    :amount,
    :currency
  ]
end
