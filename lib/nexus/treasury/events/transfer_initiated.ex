defmodule Nexus.Treasury.Events.TransferInitiated do
  @moduledoc """
  Event emitted when a transfer is initiated and its initial status is determined.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          from_currency: Types.currency(),
          to_currency: Types.currency(),
          amount: Types.money(),
          status: String.t(),
          bulk_payment_id: Types.binary_id() | nil,
          requested_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [
    :transfer_id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :status,
    :requested_at
  ]
  defstruct [
    :transfer_id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :status,
    :bulk_payment_id,
    :requested_at
  ]
end
