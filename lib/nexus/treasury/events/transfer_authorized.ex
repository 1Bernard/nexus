defmodule Nexus.Treasury.Events.TransferAuthorized do
  @moduledoc """
  Event emitted when a transfer has been authorized (e.g. after step-up).
  """
  @derive [Jason.Encoder]
  @enforce_keys [:transfer_id, :org_id, :authorized_at]
  defstruct [:transfer_id, :org_id, :actor_email, :authorized_at]
end
