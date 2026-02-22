defmodule Nexus.Organization.Aggregates.Tenant do
  @moduledoc """
  The Organization boundary. Enforces unique tenant names and issues user invitations.
  """
  defstruct [:id, :name, invitations: MapSet.new()]

  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Organization.Commands.InviteUser
  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Events.UserInvited

  # --- Provisioning ---

  def execute(%__MODULE__{id: nil}, %ProvisionTenant{} = cmd) do
    # Name must be present
    if is_nil(cmd.name) || String.trim(cmd.name) == "" do
      {:error, :name_required}
    else
      %TenantProvisioned{
        org_id: cmd.org_id,
        name: String.trim(cmd.name),
        initial_admin_email: String.downcase(String.trim(cmd.initial_admin_email)),
        provisioned_by: cmd.provisioned_by,
        provisioned_at: DateTime.utc_now()
      }
    end
  end

  def execute(%__MODULE__{id: _exists}, %ProvisionTenant{}) do
    {:error, :already_provisioned}
  end

  # --- Invitations ---

  def execute(%__MODULE__{id: id} = state, %InviteUser{} = cmd) when not is_nil(id) do
    email = String.downcase(String.trim(cmd.email))

    if MapSet.member?(state.invitations, email) do
      {:error, :email_already_invited}
    else
      %UserInvited{
        org_id: cmd.org_id,
        email: email,
        role: cmd.role,
        invited_by: cmd.invited_by,
        invitation_token: Ecto.UUID.generate(),
        invited_at: DateTime.utc_now()
      }
    end
  end

  def execute(%__MODULE__{id: nil}, %InviteUser{}) do
    {:error, :tenant_not_found}
  end

  # --- State Mutators ---

  def apply(%__MODULE__{} = state, %TenantProvisioned{} = event) do
    %{state | id: event.org_id, name: event.name}
  end

  def apply(%__MODULE__{} = state, %UserInvited{} = event) do
    %{state | invitations: MapSet.put(state.invitations, event.email)}
  end
end
