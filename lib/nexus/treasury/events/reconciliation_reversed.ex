defmodule Nexus.Treasury.Events.ReconciliationReversed do
  @moduledoc """
  Event emitted when a matched reconciliation is reversed, releasing the invoice
  and statement line back to their unmatched state.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          invoice_id: Types.binary_id(),
          statement_line_id: Types.binary_id(),
          actor_email: String.t() | nil,
          timestamp: Types.datetime()
        }

  defstruct [
    :org_id,
    :reconciliation_id,
    :invoice_id,
    :statement_line_id,
    :actor_email,
    :timestamp
  ]
end
