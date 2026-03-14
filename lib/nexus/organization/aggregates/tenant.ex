defmodule Nexus.Organization.Aggregates.Tenant do
  @moduledoc """
  The Organization boundary. Enforces unique tenant names and issues user invitations.
  """
  defstruct [
    :id,
    :name,
    status: "ACTIVE",
    modules_enabled: MapSet.new(),
    invitations: MapSet.new()
  ]

  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Organization.Commands.InviteUser
  alias Nexus.Organization.Commands.RedeemInvitation
  alias Nexus.Organization.Commands.SuspendTenant
  alias Nexus.Organization.Commands.ToggleTenantModule

  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Events.UserInvited
  alias Nexus.Organization.Events.InvitationRedeemed
  alias Nexus.Organization.Events.TenantSuspended
  alias Nexus.Organization.Events.TenantModuleToggled

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
        provisioned_at: cmd.provisioned_at
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
        invitation_token: cmd.invitation_token,
        invited_at: cmd.invited_at
      }
    end
  end

  def execute(%__MODULE__{id: nil}, %InviteUser{}) do
    {:error, :tenant_not_found}
  end

  def execute(%__MODULE__{id: id} = _state, %RedeemInvitation{} = cmd) when not is_nil(id) do
    %InvitationRedeemed{
      org_id: cmd.org_id,
      invitation_token: cmd.invitation_token,
      redeemed_by_user_id: cmd.redeemed_by_user_id,
      redeemed_at: cmd.redeemed_at
    }
  end

  # --- System Admin Actions (God-Mode) ---

  def execute(%__MODULE__{id: nil}, %SuspendTenant{}) do
    {:error, :tenant_not_found}
  end

  def execute(%__MODULE__{id: id, status: "SUSPENDED"} = _state, %SuspendTenant{})
      when not is_nil(id) do
    {:error, :already_suspended}
  end

  def execute(%__MODULE__{id: id} = _state, %SuspendTenant{} = cmd) when not is_nil(id) do
    %TenantSuspended{
      org_id: cmd.org_id,
      suspended_by: cmd.suspended_by,
      reason: cmd.reason,
      suspended_at: cmd.suspended_at
    }
  end

  def execute(%__MODULE__{id: nil}, %ToggleTenantModule{}) do
    {:error, :tenant_not_found}
  end

  def execute(%__MODULE__{id: id, status: "SUSPENDED"}, %ToggleTenantModule{})
      when not is_nil(id) do
    {:error, :tenant_suspended}
  end

  def execute(%__MODULE__{id: id, modules_enabled: modules} = _state, %ToggleTenantModule{} = cmd)
      when not is_nil(id) do
    # Only emit if the state is actually changing
    is_enabled = MapSet.member?(modules, cmd.module_name)

    if is_enabled == cmd.enabled do
      []
    else
      %TenantModuleToggled{
        org_id: cmd.org_id,
        module_name: cmd.module_name,
        enabled: cmd.enabled,
        toggled_by: cmd.toggled_by,
        toggled_at: cmd.toggled_at
      }
    end
  end

  # --- State Mutators ---

  def apply(%__MODULE__{} = state, %TenantProvisioned{} = event) do
    %{state | id: event.org_id, name: event.name}
  end

  def apply(%__MODULE__{} = state, %UserInvited{} = event) do
    %{state | invitations: MapSet.put(state.invitations, event.email)}
  end

  def apply(%__MODULE__{} = state, %TenantSuspended{}) do
    %{state | status: "SUSPENDED"}
  end

  def apply(%__MODULE__{} = state, %TenantModuleToggled{} = event) do
    modules =
      if event.enabled do
        MapSet.put(state.modules_enabled, event.module_name)
      else
        MapSet.delete(state.modules_enabled, event.module_name)
      end

    %{state | modules_enabled: modules}
  end
end

defimpl Jason.Encoder, for: Nexus.Organization.Aggregates.Tenant do
  def encode(struct, opts) do
    struct
    |> Map.from_struct()
    |> Map.update!(:modules_enabled, &MapSet.to_list/1)
    |> Map.update!(:invitations, &MapSet.to_list/1)
    |> Jason.Encode.map(opts)
  end
end
