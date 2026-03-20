defmodule Nexus.Reporting.Policies.ReportingPolicy do
  @moduledoc """
  Authorization policies for Reporting resources (Audit logs, System controls).
  """
  @behaviour Nexus.Shared.Policy

  @impl true
  @spec can?(Nexus.Shared.Policy.user() | nil, atom(), any()) :: boolean()
  def can?(nil, _action, _resource), do: false

  # Audit log access for auditors and admins
  def can?(user, _action, :audit_logs) do
    user.role in [:auditor, "auditor", :system_admin, "system_admin"]
  end

  # Default fallback
  def can?(_user, _action, _resource), do: false
end
