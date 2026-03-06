defmodule Nexus.Organization.Events.TenantSuspended do
  @derive Jason.Encoder
  defstruct [:org_id, :suspended_by, :reason, :suspended_at]
end
