defmodule Nexus.Organization.Events.TenantSuspended do
  @moduledoc """
  Event emitted when a system administrator suspends a tenant organisation.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :suspended_by, :reason, :suspended_at]
  defstruct [:org_id, :suspended_by, :reason, :suspended_at]
end
