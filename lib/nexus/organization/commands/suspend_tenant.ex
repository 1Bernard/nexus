defmodule Nexus.Organization.Commands.SuspendTenant do
  @enforce_keys [:org_id, :suspended_by, :reason]
  defstruct [:org_id, :suspended_by, :reason]
end
