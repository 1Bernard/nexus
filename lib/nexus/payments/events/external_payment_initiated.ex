defmodule Nexus.Payments.Events.ExternalPaymentInitiated do
  @moduledoc """
  Emitted when an external payment is initiated (e.g., via Paystack).
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [:payment_id, :org_id, :transfer_id, :amount, :currency, :recipient_data, :external_reference, :initiated_at]

  @type t :: %__MODULE__{
          payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          transfer_id: Types.binary_id(),
          amount: Types.money(),
          currency: Types.currency(),
          recipient_data: map(),
          external_reference: String.t(),
          initiated_at: Types.datetime()
        }
end
