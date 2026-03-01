defmodule Nexus.Treasury.Events.ReconciliationReversed do
  @derive Jason.Encoder
  defstruct [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_line_id,
    :actor_email,
    :timestamp
  ]
end
