defmodule Nexus.Reporting.Projectors.AuthIntegrityProjector do
  @moduledoc """
  Specialized projector for Authentication Integrity metrics.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.AuthIntegrityProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.StepUpVerified
  alias Nexus.Reporting.Projections.ControlMetric

  project(%StepUpVerified{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :"metric_auth_#{metadata.event_id}", %ControlMetric{
      id: metadata.event_id,
      org_id: event.org_id,
      metric_key: "auth_integrity",
      score: Decimal.new(1),
      metadata: %{
        last_event: "step_up_verified",
        causation_id: metadata.causation_id
      }
    })
  end)
end
