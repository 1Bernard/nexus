defmodule Nexus.Identity.Events.UserRoleChanged do
  @moduledoc """
  Event emitted when an administrator changes a user's role within the system.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          role: String.t(),
          actor_id: Types.binary_id(),
          changed_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :org_id, :role, :actor_id, :changed_at]
  defstruct [:user_id, :org_id, :role, :actor_id, :changed_at]
end
