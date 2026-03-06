defmodule Nexus.Organization.Events.TenantModuleToggled do
  @derive Jason.Encoder
  defstruct [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
end
