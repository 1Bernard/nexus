defmodule Nexus.Treasury.Events.TransferExecuted do
  @moduledoc """
  Event emitted when a transfer has been successfully executed.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          from_currency: Types.currency(),
          to_currency: Types.currency(),
          recipient_data: map() | nil,
          executed_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [:transfer_id, :org_id, :amount, :from_currency, :to_currency, :executed_at]
  defstruct [:transfer_id, :org_id, :amount,    :from_currency,
    :to_currency,
    :recipient_data,
    :executed_at
  ]
end
