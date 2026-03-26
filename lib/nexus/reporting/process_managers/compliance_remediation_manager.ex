defmodule Nexus.Reporting.ProcessManagers.ComplianceRemediationManager do
  @moduledoc """
  The autonomous remediation brain of Nexus.
  Listens for state changes and enforces control invariants by issuing corrective commands.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Reporting.ComplianceRemediationManager"

  @derive Jason.Encoder
  defstruct [:user_id, :org_id, :roles]

  @type t :: %__MODULE__{}

  alias Nexus.Identity.Events.{UserRegistered, UserRoleChanged}
  alias Nexus.Identity.Commands.RevokeUserRole

  @spec interested?(struct()) :: {:start | :continue, binary()} | false
  def interested?(%UserRegistered{user_id: id}), do: {:start, id}
  def interested?(%UserRoleChanged{user_id: id}), do: {:continue, id}

  # --- Handle Events (Emit Commands) ---

  @spec handle(t(), struct()) :: [struct()] | struct() | []
  def handle(pm, %UserRegistered{} = _event) do
    # When a user is registered, we check if their initial role creates a conflict.
    # We use the state in apply/2 to keep track of roles.
    check_remediation(pm)
  end

  def handle(pm, %UserRoleChanged{} = _event) do
    check_remediation(pm)
  end

  defp check_remediation(pm) do
    roles = pm.roles || []

    # Toxic Combinations (Matching Nexus.Reporting.list_sod_conflicts/1 logic):
    # 1. Initiate (trader) + Authorize (approver/admin)
    has_conflict? =
      (Enum.member?(roles, "trader") && (Enum.member?(roles, "approver") || Enum.member?(roles, "admin"))) ||
      (Enum.member?(roles, "approver") && Enum.member?(roles, "admin"))

    if has_conflict? do
      # For now, we always revoke the most powerful role (approver or admin)
      # In a real system, we'd check if the org is in 'Strict' mode.
      role_to_revoke =
        cond do
          Enum.member?(roles, "admin") -> "admin"
          Enum.member?(roles, "approver") -> "approver"
          true -> nil
        end

      if role_to_revoke do
        %RevokeUserRole{
          user_id: pm.user_id,
          org_id: pm.org_id,
          role: role_to_revoke,
          revoked_by: "system:compliance_remediation_manager",
          revoked_at: Nexus.Schema.utc_now()
        }
      else
        []
      end
    else
      []
    end
  end

  # --- Mutate State ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = pm, %UserRegistered{} = event) do
    %__MODULE__{pm | user_id: event.user_id, org_id: event.org_id, roles: [event.role]}
  end

  def apply(%__MODULE__{} = pm, %UserRoleChanged{} = event) do
    # Add role to list if not present
    new_roles = Enum.uniq([event.role | (pm.roles || [])])
    %__MODULE__{pm | roles: new_roles}
  end
end
