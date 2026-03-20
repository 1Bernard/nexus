defmodule Nexus.Organization.Events.TenantModuleToggled do
  @moduledoc """
  Event emitted when a feature module is enabled or disabled for a tenant organisation.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          module_name: String.t(),
          enabled: boolean(),
          toggled_by: String.t(),
          toggled_at: Types.datetime()
        }

  defstruct [:org_id, :module_name, :enabled, :toggled_by, :toggled_at]
end
