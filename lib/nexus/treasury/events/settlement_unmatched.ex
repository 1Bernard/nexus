defmodule Nexus.Treasury.Events.SettlementUnmatched do
  @moduledoc """
  Event emitted when an unmatched settlement exception occurs.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :statement_line_id, :amount, :currency, :reason, :timestamp]
  defstruct [
    :org_id,
    :statement_line_id,
    :amount,
    :currency,
    :reason,
    :timestamp
  ]
end
