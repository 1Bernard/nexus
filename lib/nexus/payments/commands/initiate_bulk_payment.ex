defmodule Nexus.Payments.Commands.InitiateBulkPayment do
  @moduledoc """
  Command to initiate a batch of payments.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          bulk_payment_id: Types.binary_id(),
          org_id: Types.org_id(),
          user_id: Types.binary_id(),
          payments: [map()],
          initiated_at: Types.datetime()
        }

  @enforce_keys [:bulk_payment_id, :org_id, :user_id, :payments, :initiated_at]
  defstruct [:bulk_payment_id, :org_id, :user_id, :payments, :initiated_at]

  # payment instruction map: %{amount: Decimal, currency: String, recipient_name: String, recipient_account: String, invoice_id: Types.binary_id() | nil}
end
