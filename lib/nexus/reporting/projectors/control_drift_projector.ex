defmodule Nexus.Reporting.Projectors.ControlDriftProjector do
  @moduledoc """
  Projector for the reporting_control_drifts table.
  Captures real-time deviations in system controls for the CCM dashboard.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.ControlDriftProjector",
    repo: Nexus.Repo,
    consistency: :strong

  require Logger

  alias Nexus.Identity.Events.UserRoleChanged
  alias Nexus.Treasury.Events.PolicyModeChanged
  alias Nexus.Intelligence.Events.AnomalyDetected
  alias Nexus.Reporting.Projections.ControlDrift

  project(%UserRoleChanged{} = event, metadata, fn multi ->
    Logger.debug("[ControlDriftProjector] Handling UserRoleChanged for user #{event.user_id}")
    # Detect SoD Drift
    conflicts = Nexus.Reporting.list_sod_conflicts(event.org_id)
    drift_score = if Enum.empty?(conflicts), do: 0, else: length(conflicts) * 10

    upsert_drift(multi, metadata.event_id, %{
      id: metadata.event_id,
      org_id: event.org_id,
      control_key: "Segregation of Duties",
      current_value: "#{length(conflicts)} active conflicts",
      drift_score: Decimal.new(drift_score),
      last_changed_at: event.changed_at
    })
  end)

  project(%PolicyModeChanged{} = event, metadata, fn multi ->
    # Detect Policy Drift
    upsert_drift(multi, metadata.event_id, %{
      id: metadata.event_id,
      org_id: event.org_id,
      control_key: "Treasury Policy",
      original_value: "Standard",
      current_value: event.mode,
      # Threshold change is a minor drift
      drift_score: 5,
      last_changed_at: event.changed_at
    })
  end)

  project(%AnomalyDetected{} = event, metadata, fn multi ->
    Logger.debug(
      "[ControlDriftProjector] Handling AnomalyDetected for org #{event.org_id}: #{event.reason}"
    )

    # Detect Anomaly Drift
    upsert_drift(multi, metadata.event_id, %{
      id: metadata.event_id,
      org_id: event.org_id,
      control_key: "Unauthorized Movement",
      original_value: "Healthy",
      current_value: event.reason,
      # Critical drift
      drift_score: Decimal.new("50"),
      last_changed_at: event.flagged_at
    })
  end)

  defp upsert_drift(multi, event_id, attrs) do
    # Elite standard: ensure timestamps are proper DateTime structs for Ecto
    last_changed_at = ensure_datetime(attrs.last_changed_at)

    # Elite standard: use Ecto.Multi.insert with on_conflict for clean state tracking
    Ecto.Multi.insert(
      multi,
      :"drift_#{event_id}",
      %ControlDrift{
        id: attrs.id,
        org_id: attrs.org_id,
        control_key: attrs.control_key,
        original_value: Map.get(attrs, :original_value),
        current_value: attrs.current_value,
        drift_score: attrs.drift_score,
        last_changed_at: last_changed_at
      },
      on_conflict: {:replace, [:current_value, :drift_score, :last_changed_at]},
      conflict_target: [:org_id, :control_key]
    )
  end

  defp ensure_datetime(%DateTime{} = dt), do: dt
  defp ensure_datetime(nil), do: DateTime.utc_now()

  defp ensure_datetime(iso_str) when is_binary(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
