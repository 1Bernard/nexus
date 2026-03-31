defmodule Nexus.Reporting.Projectors.EscalationIntegrityProjector do
  @moduledoc """
  Specialized projector for escalation integrity metrics.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.EscalationIntegrityProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Treasury.Events.{ReconciliationProposed, TransactionReconciled}
  alias Nexus.Intelligence.Events.AnomalyDetected
  alias Nexus.Reporting.Projections.ControlMetric

  project(%ReconciliationProposed{} = event, metadata, fn multi ->
    id = metadata.event_id

    Ecto.Multi.insert(multi, :"metric_reconciliation_proposal_#{id}", %ControlMetric{
      id: id,
      org_id: event.org_id,
      metric_key: "escalation_integrity",
      score: Decimal.new(1),
      metadata: %{
        action: "reconciliation_proposed",
        reconciliation_id: event.reconciliation_id,
        variance: Nexus.Schema.parse_decimal(event.variance),
        causation_id: metadata.causation_id
      }
    })
  end)

  project(%TransactionReconciled{} = event, metadata, fn multi ->
    id = metadata.event_id

    Ecto.Multi.insert(multi, :"metric_reconciliation_final_#{id}", %ControlMetric{
      id: id,
      org_id: event.org_id,
      metric_key: "escalation_integrity",
      score: Decimal.new(1),
      metadata: %{
        action: "transaction_reconciled",
        reconciliation_id: event.reconciliation_id,
        causation_id: metadata.causation_id
      }
    })
  end)

  project(%AnomalyDetected{} = event, metadata, fn multi ->
    id = metadata.event_id

    Ecto.Multi.insert(multi, :"metric_anomaly_escalation_#{id}", %ControlMetric{
      id: id,
      org_id: event.org_id,
      metric_key: "escalation_integrity",
      score: Decimal.new(1),
      metadata: %{
        action: "manual_audit",
        reason: event.reason,
        score: event.score,
        causation_id: metadata.causation_id
      }
    })
  end)
end
