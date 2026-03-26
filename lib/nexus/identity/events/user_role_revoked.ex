defmodule Nexus.Identity.Events.UserRoleRevoked do
  @moduledoc """
  Event emitted when a user role is revoked via remediation.
  """
  alias Nexus.Types
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          role: String.t(),
          revoked_by: String.t(),
          revoked_at: Types.datetime()
        }

  defstruct [:user_id, :org_id, :role, :revoked_by, :revoked_at]
end
