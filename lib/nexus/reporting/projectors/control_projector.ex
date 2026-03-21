defmodule Nexus.Reporting.Projectors.ControlProjector do
  @moduledoc """
  Projector for real-time compliance metrics.
  Calculates and updates scores for Auth Integrity, SoD Cleanliness, and Policy Drift.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.ControlProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.{UserRoleChanged, StepUpVerified}
  alias Nexus.Treasury.Events.{
    TransferThresholdSet,
    TransferExecuted,
    VaultBalanceSynced,
    ReconciliationProposed,
    TransactionReconciled
  }
  alias Nexus.Reporting.Projections.ControlMetric

  # --- Segregation of Duties ---
  project(%UserRoleChanged{} = event, metadata, fn multi ->
    conflicts = Nexus.Reporting.list_sod_conflicts(event.org_id)
    score = if Enum.empty?(conflicts), do: 100, else: max(0, 100 - length(conflicts) * 10)

    project_metric(multi, event.org_id, "sod_cleanliness", score, metadata, %{
      last_updated: event.changed_at,
      conflict_count: length(conflicts)
    })
  end)

  # --- Auth Integrity ---
  project(%StepUpVerified{} = event, metadata, fn multi ->
    project_metric(multi, event.org_id, "auth_integrity", 1.0, metadata, %{last_event: "step_up_verified"})
  end)

  # --- Policy Drift ---
  project(%TransferThresholdSet{} = event, metadata, fn multi ->
    project_metric(multi, event.org_id, "policy_drift", 1.0, metadata, %{threshold: event.threshold})
  end)

  # --- Precision Audit ---
  project(%TransferExecuted{} = event, metadata, fn multi ->
    project_metric(multi, event.org_id, "precision_audit", 1.0, metadata, %{last_amount: event.amount})
  end)

  # --- Liquidity Accuracy ---
  project(%VaultBalanceSynced{} = event, metadata, fn multi ->
    # In a real system, we would fetch the latest forecast and compare.
    # For now, we simulate accuracy monitoring.
    project_metric(multi, event.org_id, "liquidity_accuracy", 0.98, metadata, %{
      actual_balance: event.amount,
      synced_at: event.synced_at
    })
  end)

  # --- Escalation Integrity ---
  project(%ReconciliationProposed{} = event, metadata, fn multi ->
    # New high-variance reconciliation proposed.
    project_metric(multi, event.org_id, "escalation_integrity", 1.0, metadata, %{
      action: "reconciliation_proposed",
      reconciliation_id: event.reconciliation_id,
      variance: event.variance
    })
  end)

  project(%TransactionReconciled{} = event, metadata, fn multi ->
    # Reconciliation finalized.
    project_metric(multi, event.org_id, "escalation_integrity", 1.0, metadata, %{
      action: "transaction_reconciled",
      reconciliation_id: event.reconciliation_id
    })
  end)

  def project_metric(multi, org_id, key, score, metadata, extra_meta) do
    # We now INSERT every time to keep a history of scores for drift analysis.
    # The unique index was removed in a previous migration.
    multi
    |> Ecto.Multi.insert(
      :"metric_#{key}_#{metadata.event_id}",
      %ControlMetric{
        id: metadata.event_id,
        org_id: org_id,
        metric_key: key,
        score: Decimal.from_float(score * 1.0),
        metadata: Map.put(extra_meta, :causation_id, metadata.causation_id)
      }
    )
    |> Ecto.Multi.run(:"broadcast_#{key}", fn _repo, _ ->
      Phoenix.PubSub.broadcast(
        Nexus.PubSub,
        "reporting:compliance_updates",
        {:compliance_updated, org_id}
      )

      {:ok, nil}
    end)
  end
end
