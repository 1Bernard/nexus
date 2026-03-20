defmodule Nexus.Organization.Commands.SuspendTenant do
  @moduledoc """
  Command to suspend a tenant's access to the platform.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          suspended_by: String.t(),
          reason: String.t(),
          suspended_at: Types.datetime()
        }

  @enforce_keys [:org_id, :suspended_by, :reason, :suspended_at]
  defstruct [:org_id, :suspended_by, :reason, :suspended_at]
end
