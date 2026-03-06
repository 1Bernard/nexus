defmodule Nexus.Organization.Commands.ProvisionTenant do
  @moduledoc """
  Dispatched by a system_admin to create a new Tenant organization boundary.
  """
  @enforce_keys [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
  defstruct [:org_id, :name, :initial_admin_email, :provisioned_by, :provisioned_at]
end
