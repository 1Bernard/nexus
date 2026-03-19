defmodule Nexus.Treasury.Commands.RequestTransfer do
  @moduledoc """
  Command to initiate a fund transfer.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          transfer_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          from_currency: Types.currency(),
          to_currency: Types.currency(),
          amount: Types.money(),
          threshold: Types.money() | nil,
          bulk_payment_id: Types.binary_id() | nil,
          recipient_data: map() | nil,
          requested_at: Types.datetime()
        }
  @enforce_keys [
    :transfer_id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :requested_at
  ]
  defstruct [
    :transfer_id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :threshold,
    :bulk_payment_id,
    :recipient_data,
    :requested_at
  ]
end
