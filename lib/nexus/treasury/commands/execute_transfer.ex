defmodule Nexus.Treasury.Commands.ExecuteTransfer do
  @moduledoc """
  Command to execute an authorized transfer.
  """
  @enforce_keys [:transfer_id, :org_id, :executed_at]
  defstruct [:transfer_id, :org_id, :executed_at]
end
