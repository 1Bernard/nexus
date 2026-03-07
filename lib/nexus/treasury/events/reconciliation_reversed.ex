defmodule Nexus.Treasury.Events.ReconciliationReversed do
  @moduledoc """
  Event emitted when a matched reconciliation is reversed, releasing the invoice
  and statement line back to their unmatched state.
  """
  @derive Jason.Encoder
  @enforce_keys [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_line_id,
    :actor_email,
    :timestamp
  ]
  defstruct [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_line_id,
    :actor_email,
    :timestamp
  ]
end
