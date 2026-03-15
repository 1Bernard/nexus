defmodule Nexus.Treasury.Commands.ProposeReconciliation do
  @moduledoc """
  Command dispatched when a user proposes matching an invoice to a bank statement line.
  Carries full reconciliation context including optional variance details.
  """
  alias Nexus.Types

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
