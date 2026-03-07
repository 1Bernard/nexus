defmodule Nexus.Treasury.Events.TransferInitiated do
  @moduledoc """
  Event emitted when a transfer is initiated and its initial status is determined.
  """
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
