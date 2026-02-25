defmodule Nexus.Treasury.Commands.RequestTransfer do
  @moduledoc """
  Command to initiate a fund transfer.
  """
  @enforce_keys [:transfer_id, :org_id, :user_id, :from_currency, :to_currency, :amount]
  defstruct [:transfer_id, :org_id, :user_id, :from_currency, :to_currency, :amount]
end
