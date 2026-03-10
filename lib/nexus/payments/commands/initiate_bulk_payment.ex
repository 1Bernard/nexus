defmodule Nexus.Payments.Commands.InitiateBulkPayment do
  @moduledoc """
  Command to initiate a batch of payments.
  """
  @enforce_keys [:bulk_payment_id, :org_id, :user_id, :payments, :initiated_at]
  defstruct [:bulk_payment_id, :org_id, :user_id, :payments, :initiated_at]
  # payment instruction map: %{amount: Decimal, currency: String, recipient_name: String, recipient_account: String, invoice_id: String | nil}
end
