defmodule Nexus.Organization.Commands.ToggleTenantModule do
  @enforce_keys [:org_id, :module_name, :enabled, :toggled_by]
  defstruct [:org_id, :module_name, :enabled, :toggled_by]
end
