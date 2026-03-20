defmodule Nexus.Tenant.Commands.ProvisionOrganization do
  @moduledoc """
  The Genesis command for a new Organization (tenant).
  This command is allowed to pass through the TenantGate middleware
  because it is responsible for establishing the org_id context.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          name: String.t(),
          plan: String.t(),
          owner_id: Types.binary_id() | nil
        }

  @enforce_keys [:org_id, :name, :plan]
  defstruct [:org_id, :name, :plan, :owner_id]
end
