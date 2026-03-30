defmodule Nexus.Treasury.Events.InvoiceAddedToNetting do
  @moduledoc """
  Emitted when an ERP invoice is successfully linked to a netting cycle.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [
    :netting_id,
    :org_id,
    :invoice_id,
    :subsidiary,
    :amount,
    :currency,
    :added_at
  ]

  @type t :: %__MODULE__{
          netting_id: Types.binary_id(),
          org_id: Types.org_id(),
          invoice_id: Types.binary_id(),
          subsidiary: String.t(),
          amount: Decimal.t(),
          currency: Types.currency(),
          added_at: Types.datetime()
        }
end
