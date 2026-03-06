defmodule Nexus.Organization.Commands.SuspendTenant do
  @moduledoc """
  Command to suspend a tenant's access to the platform.
  """
  @enforce_keys [:org_id, :suspended_by, :reason, :suspended_at]
  defstruct [:org_id, :suspended_by, :reason, :suspended_at]
end
