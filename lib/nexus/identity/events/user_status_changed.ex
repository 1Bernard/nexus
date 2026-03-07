defmodule Nexus.Identity.Events.UserStatusChanged do
  @moduledoc """
  Event emitted when an administrator changes a user's account status.
  """
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :status, :actor_id, :changed_at]
  defstruct [:user_id, :status, :actor_id, :changed_at]
end
