defmodule Nexus.Identity.Events.UserRoleChanged do
  @moduledoc """
  Event emitted when an administrator changes a user's role within the system.
  """
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :role, :actor_id, :changed_at]
  defstruct [:user_id, :role, :actor_id, :changed_at]
end
