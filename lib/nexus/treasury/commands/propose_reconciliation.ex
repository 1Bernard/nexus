defmodule Nexus.Treasury.Commands.ProposeReconciliation do
  @moduledoc """
  Command dispatched when a user proposes matching an invoice to a bank statement line.
  Carries full reconciliation context including optional variance details.
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
