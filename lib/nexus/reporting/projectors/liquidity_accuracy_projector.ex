defmodule Nexus.Reporting.Projectors.LiquidityAccuracyProjector do
  @moduledoc """
  Specialized projector for liquidity accuracy metrics.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.LiquidityAccuracyProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Treasury.Events.VaultBalanceSynced
  alias Nexus.Reporting.Projections.ControlMetric

  project(%VaultBalanceSynced{} = event, metadata, fn multi ->
    # Elite Rule 9: Type-safe parsing
    amount = Nexus.Schema.parse_decimal(event.amount)
    id = metadata.event_id

    # In a real system, we'd compare this against the latest forecast.
    # For now, we simulate accuracy at 98%.
    Ecto.Multi.insert(multi, :"metric_liquidity_#{id}", %ControlMetric{
      id: id,
      org_id: event.org_id,
      metric_key: "liquidity_accuracy",
      score: Decimal.new("0.98"),
      metadata: %{
        actual_balance: amount,
        synced_at: Nexus.Schema.parse_datetime(event.synced_at),
        causation_id: metadata.causation_id
      }
    })
  end)
end
