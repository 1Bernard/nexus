defmodule Nexus.Identity.Events.UserStatusChanged do
  @moduledoc """
  Event emitted when an administrator changes a user's account status.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          status: String.t(),
          actor_id: Types.binary_id(),
          changed_at: Types.datetime()
        }
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :org_id, :status, :actor_id, :changed_at]
  defstruct [:user_id, :org_id, :status, :actor_id, :changed_at]
end
