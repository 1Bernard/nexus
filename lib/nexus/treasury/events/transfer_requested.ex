defmodule Nexus.Treasury.Events.TransferRequested do
  @moduledoc """
  Event emitted when a transfer is initiated but may require step-up authorisation.
  """
  @derive [Jason.Encoder]
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
    :bulk_payment_id,
    :requested_at
  ]
end
