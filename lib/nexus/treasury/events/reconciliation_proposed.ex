defmodule Nexus.Treasury.Events.ReconciliationProposed do
  @moduledoc """
  Event emitted when a user proposes a match between an invoice and a bank statement line.
  Carries full reconciliation context; variance fields are optional.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          invoice_id: Types.binary_id(),
          statement_id: Types.binary_id(),
          statement_line_id: Types.binary_id(),
          amount: Types.money(),
          variance: Types.money() | nil,
          variance_reason: String.t() | nil,
          actor_email: String.t(),
          currency: Types.currency(),
          timestamp: Types.datetime()
        }

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
