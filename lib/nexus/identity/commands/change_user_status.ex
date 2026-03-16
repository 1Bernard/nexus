defmodule Nexus.Identity.Commands.ChangeUserStatus do
  @moduledoc """
  Command to change a user's account status (active, suspended, blocked).
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          status: String.t(),
          actor_id: Types.binary_id(),
          changed_at: Types.datetime()
        }
  @enforce_keys [:user_id, :org_id, :status, :actor_id, :changed_at]
  defstruct [:user_id, :org_id, :status, :actor_id, :changed_at]
end
