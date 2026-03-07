defmodule Nexus.Treasury.Commands.ReconcileTransaction do
  @moduledoc """
  Command to record a successful match between an invoice and a statement line.
  """
  @enforce_keys [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_id,
    :statement_line_id,
    :amount,
    :actor_email,
    :currency,
    :timestamp
  ]
  defstruct [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_id,
    :statement_line_id,
    :amount,
    :variance,
    :variance_reason,
    :actor_email,
    :currency,
    :timestamp
  ]
end
