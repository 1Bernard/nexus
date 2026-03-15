defmodule Nexus.Treasury.Events.SettlementUnmatched do
  @moduledoc """
  Event emitted when an unmatched settlement exception occurs.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          statement_line_id: Types.binary_id(),
          amount: Types.money(),
          currency: Types.currency(),
          reason: String.t(),
          timestamp: Types.datetime()
        }
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
