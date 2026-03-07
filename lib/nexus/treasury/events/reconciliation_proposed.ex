defmodule Nexus.Treasury.Events.ReconciliationProposed do
  @moduledoc """
  Event emitted when a user proposes a match between an invoice and a bank statement line.
  Carries full reconciliation context; variance fields are optional.
  """
  @derive Jason.Encoder
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
