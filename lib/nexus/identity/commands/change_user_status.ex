defmodule Nexus.Identity.Commands.ChangeUserStatus do
  @moduledoc """
  Command to change a user's account status (active, suspended, blocked).
  """
  @enforce_keys [:user_id, :org_id, :status, :actor_id, :changed_at]
  defstruct [:user_id, :org_id, :status, :actor_id, :changed_at]
end
