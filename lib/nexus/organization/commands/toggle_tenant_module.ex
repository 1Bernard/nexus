defmodule Nexus.Organization.Commands.ToggleTenantModule do
  @moduledoc """
  Command to enable or disable a specific feature module for a tenant.
  """
  @enforce_keys [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
  defstruct [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
end
