defmodule Nexus.Payments.Commands.InitiateExternalPayment do
  @moduledoc """
  Command to initiate a payment via an external rail (e.g. Paystack).
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          transfer_id: Types.binary_id(),
          amount: Types.money(),
          currency: Types.currency(),
          recipient_data: map(),
          initiated_at: Types.datetime()
        }

  @enforce_keys [
    :payment_id,
    :org_id,
    :transfer_id,
    :amount,
    :currency,
    :recipient_data,
    :initiated_at
  ]
  defstruct [
    :payment_id,
    :org_id,
    :transfer_id,
    :amount,
    :currency,
    :recipient_data,
    :initiated_at
  ]
end
