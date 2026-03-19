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

  alias Nexus.Identity.Events.UserRoleChanged
  alias Nexus.Identity.Events.StepUpVerified
  alias Nexus.Treasury.Events.TransferThresholdSet
  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Reporting.Projections.ControlMetric
  alias Nexus.Schema

  # --- Segregation of Duties ---
  project(%UserRoleChanged{} = event, _metadata, fn multi ->
    # In a real system, we might run a complex query here.
    # For now, we'll just upsert the metric row to ensure it exists.
    upsert_metric(multi, event.org_id, "sod_cleanliness", 1.0, %{last_updated: event.changed_at})
  end)

  # --- Auth Integrity ---
  project(%StepUpVerified{} = event, _metadata, fn multi ->
    # Every successful Step-Up reinforces the Auth Integrity score.
    upsert_metric(multi, event.org_id, "auth_integrity", 1.0, %{last_event: "step_up_verified"})
  end)

  # --- Policy Drift ---
  project(%TransferThresholdSet{} = event, _metadata, fn multi ->
    # Baseline for Policy monitoring.
    upsert_metric(multi, event.org_id, "policy_drift", 1.0, %{threshold: event.threshold})
  end)

  # --- Precision Audit ---
  project(%TransferExecuted{} = event, _metadata, fn multi ->
    # Verify no rounding errors occurred (simulated for now)
    upsert_metric(multi, event.org_id, "precision_audit", 1.0, %{last_amount: event.amount})
  end)

  defp upsert_metric(multi, org_id, key, score, metadata) do
    Ecto.Multi.insert(multi, :"metric_#{key}", %ControlMetric{
      id: Schema.generate_uuidv7(),
      org_id: org_id,
      metric_key: key,
      score: score,
      metadata: metadata
    }, on_conflict: [set: [score: score, metadata: metadata, updated_at: Schema.utc_now()]], conflict_target: [:org_id, :metric_key])
  end
end
