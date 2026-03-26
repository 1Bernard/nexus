defmodule Nexus.Identity.Commands.RevokeUserRole do
  @moduledoc """
  Command to programmatically revoke a specific role from a user.
  Used by the Compliance Remediation Manager for autonomous control enforcement.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          role: String.t(),
          revoked_by: String.t(),
          revoked_at: Types.datetime()
        }

  @enforce_keys [:user_id, :org_id, :role]
  defstruct [:user_id, :org_id, :role, :revoked_by, :revoked_at]
end
