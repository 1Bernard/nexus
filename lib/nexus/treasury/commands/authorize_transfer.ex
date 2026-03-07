defmodule Nexus.Treasury.Commands.AuthorizeTransfer do
  @moduledoc """
  Command to authorize a previously initiated pending transfer.
  """
  @enforce_keys [:transfer_id, :org_id, :authorized_at]
  defstruct [:transfer_id, :org_id, :actor_email, :authorized_at]
end
