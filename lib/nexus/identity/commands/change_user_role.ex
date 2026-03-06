defmodule Nexus.Identity.Commands.ChangeUserRole do
  @moduledoc """
  Command to change a user's role.
  """
  @enforce_keys [:user_id, :role, :actor_id, :changed_at]
  defstruct [:user_id, :role, :actor_id, :changed_at]
end
