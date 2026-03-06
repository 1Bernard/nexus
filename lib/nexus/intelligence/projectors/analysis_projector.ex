defmodule Nexus.Intelligence.Projectors.AnalysisProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Intelligence.AnalysisProjector"

  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored, AnomalyResolved}
  alias Nexus.Treasury.Events.SettlementUnmatched
  alias Nexus.Intelligence.Projections.Analysis
  require Logger

  project(%AnomalyDetected{} = event, _metadata, fn multi ->
    attrs = %{
      id: event.analysis_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      type: "anomaly",
      score: event.score,
      reason: event.reason,
      flagged_at: Nexus.Schema.parse_datetime(event.flagged_at)
    }

    Ecto.Multi.insert(multi, :intelligence_analysis, Analysis.changeset(%Analysis{}, attrs))
  end)

  project(%SettlementUnmatched{} = event, _metadata, fn multi ->
    attrs = %{
      id: event.statement_line_id,
      org_id: event.org_id,
      source_id: event.statement_line_id,
      type: "anomaly",
      score: 1.0,
      reason: "Reconciliation Failure: #{event.reason} (#{event.amount} #{event.currency})",
      flagged_at: Nexus.Schema.parse_datetime(event.timestamp)
    }

    Ecto.Multi.insert(multi, :intelligence_analysis, Analysis.changeset(%Analysis{}, attrs))
  end)

  project(%SentimentScored{} = event, _metadata, fn multi ->
    attrs = %{
      id: event.analysis_id,
      org_id: event.org_id,
      source_id: event.source_id,
      type: "sentiment",
      sentiment: event.sentiment,
      confidence: event.confidence,
      scored_at: Nexus.Schema.parse_datetime(event.scored_at)
    }

    Ecto.Multi.insert(multi, :intelligence_analysis, Analysis.changeset(%Analysis{}, attrs))
  end)

  project(%AnomalyResolved{} = event, _metadata, fn multi ->
    target_id = ensure_uuid(event.analysis_id)

    Ecto.Multi.delete_all(
      multi,
      :intelligence_analysis_resolved,
      Ecto.Query.where(Analysis, id: ^target_id)
    )
  end)

  defp ensure_uuid(id) when is_binary(id) do
    id
    |> String.replace_prefix("anm-", "")
    |> String.trim()
  end
end
