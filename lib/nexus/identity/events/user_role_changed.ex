defmodule Nexus.Identity.Events.UserRoleChanged do
  @derive [Jason.Encoder]
  defstruct [:user_id, :role, :actor_id, :changed_at]
end
