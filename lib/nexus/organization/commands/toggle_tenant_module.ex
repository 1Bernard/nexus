defmodule Nexus.Organization.Commands.ToggleTenantModule do
  @moduledoc """
  Command to enable or disable a specific feature module for a tenant.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          module_name: String.t(),
          enabled: boolean(),
          toggled_by: String.t(),
          toggled_at: Types.datetime()
        }

  @enforce_keys [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
  defstruct [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
end
