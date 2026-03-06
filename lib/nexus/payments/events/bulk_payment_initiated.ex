defmodule Nexus.Payments.Events.BulkPaymentInitiated do
  @moduledoc """
  Event emitted when a bulk payment batch is initiated.
  """
  @derive Jason.Encoder
  defstruct [
    :bulk_payment_id,
    :org_id,
    :user_id,
    :payments,
    :total_amount,
    :count,
    :initiated_at
  ]
end
