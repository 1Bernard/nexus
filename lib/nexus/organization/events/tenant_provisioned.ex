defmodule Nexus.Organization.Events.TenantProvisioned do
  @moduledoc """
  Emitted when a new Tenant is provisioned by a system admin.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
  defstruct [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
end
