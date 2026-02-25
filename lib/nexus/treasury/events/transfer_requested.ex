defmodule Nexus.Treasury.Events.TransferRequested do
  @moduledoc """
  Event emitted when a transfer is initiated but may require authorization.
  """
  @derive [Jason.Encoder]
  defstruct [
    :transfer_id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :requested_at
  ]
end
