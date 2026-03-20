defmodule Nexus.Organization.Policies.OrganizationPolicy do
  @moduledoc """
  Authorization policies for Organization resources (Tenants, Invitations, Memberships).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Org management (invites, settings) requires org_admin or system_admin
  def can?(user, _action, :org_management) do
    user.role in [:org_admin, "org_admin", :system_admin, "system_admin"]
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
