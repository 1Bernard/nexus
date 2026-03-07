defmodule Nexus.Organization.Events.TenantModuleToggled do
  @moduledoc """
  Event emitted when a feature module is enabled or disabled for a tenant organisation.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
  defstruct [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
end
