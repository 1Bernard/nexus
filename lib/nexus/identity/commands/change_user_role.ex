defmodule Nexus.Identity.Commands.ChangeUserRole do
  @moduledoc """
  Command to change a user's role.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          role: String.t(),
          actor_id: Types.binary_id(),
          changed_at: Types.datetime()
        }
  @enforce_keys [:user_id, :org_id, :role, :actor_id, :changed_at]
  defstruct [:user_id, :org_id, :role, :actor_id, :changed_at]
end
