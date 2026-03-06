defmodule Nexus.Payments.Commands.FinalizeBulkPayment do
  @moduledoc """
  Internal command used by the saga to complete a bulk batch.
  """
  @enforce_keys [:bulk_payment_id, :org_id, :completed_at]
  defstruct [:bulk_payment_id, :org_id, :completed_at]
end
