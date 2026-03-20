defmodule Nexus.Organization.Events.TenantProvisioned do
  @moduledoc """
  Emitted when a new Tenant is provisioned by a system admin.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          name: String.t(),
          initial_admin_email: String.t(),
          provisioned_by: String.t(),
          provisioned_at: Types.datetime()
        }

  defstruct [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
end
