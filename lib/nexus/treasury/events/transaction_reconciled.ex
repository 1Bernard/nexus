defmodule Nexus.Treasury.Events.TransactionReconciled do
  @moduledoc """
  Event emitted when a transaction is successfully reconciled.
  """
  @derive Jason.Encoder
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
