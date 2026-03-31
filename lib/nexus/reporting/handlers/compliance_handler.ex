defmodule Nexus.Reporting.Handlers.ComplianceHandler do
  @moduledoc """
  Handles real-time side effects for the compliance domain.
  Ensures that PubSub broadcasts are not duplicated during projection replays.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Reporting.ComplianceHandler",
    consistency: :eventual

  alias Nexus.Identity.Events.StepUpVerified
  alias Nexus.Identity.Events.UserRoleChanged
  alias Nexus.Treasury.Events.{
    TransferThresholdSet,
    VaultBalanceSynced,
    ReconciliationProposed,
    TransactionReconciled
  }

  def handle(%UserRoleChanged{org_id: org_id}, _metadata), do: broadcast(org_id)
  def handle(%StepUpVerified{org_id: org_id}, _metadata), do: broadcast(org_id)
  def handle(%TransferThresholdSet{org_id: org_id}, _metadata), do: broadcast(org_id)
  def handle(%VaultBalanceSynced{org_id: org_id}, _metadata), do: broadcast(org_id)
  def handle(%ReconciliationProposed{org_id: org_id}, _metadata), do: broadcast(org_id)
  def handle(%TransactionReconciled{org_id: org_id}, _metadata), do: broadcast(org_id)

  defp broadcast(org_id) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "reporting:compliance_updates",
      {:compliance_updated, org_id}
    )

    :ok
  end
end
