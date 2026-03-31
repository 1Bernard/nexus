defmodule Nexus.Reporting.Projectors.SodProjector do
  @moduledoc """
  Specialized projector for Segregation of Duties (SoD) metrics.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.SodProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.UserRoleChanged
  alias Nexus.Reporting.Projections.ControlMetric

  project(%UserRoleChanged{} = event, metadata, fn multi ->
    conflicts = Nexus.Reporting.list_sod_conflicts(event.org_id)
    score = if Enum.empty?(conflicts), do: 100, else: max(0, 100 - length(conflicts) * 10)

    # Note: Scoring is 100-based here to reflect cleanliness
    Ecto.Multi.insert(multi, :"metric_sod_#{metadata.event_id}", %ControlMetric{
      id: metadata.event_id,
      org_id: event.org_id,
      metric_key: "sod_cleanliness",
      score: Decimal.new(score),
      metadata: %{
        last_updated: event.changed_at,
        conflict_count: length(conflicts),
        causation_id: metadata.causation_id
      }
    })
  end)
end
