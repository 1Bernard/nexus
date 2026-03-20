defmodule Nexus.Organization.Commands.ProvisionTenant do
  @moduledoc """
  Dispatched by a system_admin to create a new Tenant organization boundary.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          name: String.t(),
          initial_admin_email: String.t(),
          provisioned_by: String.t(),
          provisioned_at: Types.datetime()
        }

  @enforce_keys [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
  defstruct [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
end
