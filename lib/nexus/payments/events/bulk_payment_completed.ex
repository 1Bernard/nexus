defmodule Nexus.Payments.Events.BulkPaymentCompleted do
  @moduledoc """
  Event emitted when a bulk payment batch is fully processed.
  """
  @derive Jason.Encoder
  @enforce_keys [:bulk_payment_id, :org_id, :completed_at]
  defstruct [:bulk_payment_id, :org_id, :completed_at]
end
