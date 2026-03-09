defmodule Nexus.Treasury.Events.TransferExecuted do
  @moduledoc """
  Event emitted when a transfer has been successfully executed.
  """
  @derive [Jason.Encoder]
  @enforce_keys [:transfer_id, :org_id, :amount, :from_currency, :to_currency, :executed_at]
  defstruct [:transfer_id, :org_id, :amount, :from_currency, :to_currency, :executed_at]
end
