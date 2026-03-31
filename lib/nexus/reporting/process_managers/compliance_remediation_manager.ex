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
  alias Nexus.Intelligence.Events.AnomalyDetected
  alias Nexus.Identity.Commands.RevokeUserRole
  alias Nexus.CrossDomain.Commands.CreateNotification

  @spec interested?(struct()) :: {:start | :continue, binary()} | false
  def interested?(%UserRegistered{user_id: id}), do: {:start, id}
  def interested?(%UserRoleChanged{user_id: id}), do: {:continue, id}
  def interested?(%AnomalyDetected{org_id: id}), do: {:start, id} # Start by Org for Anomaly

  # --- Handle Events (Emit Commands) ---

  @spec handle(t(), struct()) :: [struct()] | struct() | []
  def handle(pm, %UserRegistered{role: role} = _event) do
    # When a user is registered, we check if their initial role creates a conflict.
    check_remediation(pm, role)
  end

  def handle(pm, %UserRoleChanged{role: role} = _event) do
    check_remediation(pm, role)
  end

  def handle(_pm, %AnomalyDetected{} = event) do
    # When an anomaly is detected, we immediately notify for remediation.
    # In a real system, we'd look up the active treasury manager for this org.
    [
      %CreateNotification{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: event.org_id,
        user_id: nil, # Broadcast or target admin
        type: "compliance_alert",
        title: "Unauthorized Movement Detected",
        body: "AI Sentinel detected an anomaly: #{event.reason}. Immediate remediation required.",
        metadata: %{analysis_id: event.analysis_id, resource_id: event.resource_id}
      }
    ]
  end

  defp check_remediation(pm, new_role) do
    roles = if new_role, do: Enum.uniq([new_role | (pm.roles || [])]), else: pm.roles || []

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
        [
          %RevokeUserRole{
            user_id: pm.user_id,
            org_id: pm.org_id,
            role: role_to_revoke,
            revoked_by: "system:compliance_remediation_manager",
            revoked_at: Nexus.Schema.utc_now()
          },
          %Nexus.CrossDomain.Commands.CreateNotification{
            id: Nexus.Schema.generate_uuidv7(),
            org_id: pm.org_id,
            user_id: pm.user_id,
            type: "compliance_alert",
            title: "Automated SoD Remediation",
            body: "High-risk Segregation of Duties violation detected. The '#{role_to_revoke}' role has been automatically revoked for remediation.",
            metadata: %{user_id: pm.user_id, revoked_role: role_to_revoke}
          }
        ]
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
    # event.role is a single role string
    new_roles = Enum.uniq([event.role | (pm.roles || [])])
    %__MODULE__{pm | roles: new_roles}
  end

  def apply(%__MODULE__{} = pm, %AnomalyDetected{} = event) do
    %__MODULE__{pm | org_id: event.org_id}
  end
end
