defmodule Nexus.Intelligence.Projectors.AnalysisProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Intelligence.AnalysisProjector"

  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored}
  alias Nexus.Treasury.Events.SettlementUnmatched
  alias Nexus.Intelligence.Projections.Analysis
  require Logger

  project(%AnomalyDetected{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :intelligence_analysis, %Analysis{
      id: event.analysis_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      type: "anomaly",
      score: event.score,
      reason: event.reason,
      flagged_at: parse_datetime(event.flagged_at)
    })
  end)

  project(%SettlementUnmatched{} = event, _metadata, fn multi ->
    # Generate a deterministic ID based on statement_line_id for idempotency if it reappears
    # Alternatively, use a fresh UUID if multiple anomalies can exist for one line
    id = event.statement_line_id

    Ecto.Multi.insert(multi, :intelligence_analysis, %Analysis{
      id: id,
      org_id: event.org_id,
      source_id: event.statement_line_id,
      type: "anomaly",
      score: 1.0,
      reason: "Reconciliation Failure: #{event.reason} (#{event.amount} #{event.currency})",
      flagged_at: parse_datetime(event.timestamp)
    })
  end)

  project(%SentimentScored{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :intelligence_analysis, %Analysis{
      id: event.analysis_id,
      org_id: event.org_id,
      source_id: event.source_id,
      type: "sentiment",
      sentiment: event.sentiment,
      confidence: event.confidence,
      scored_at: parse_datetime(event.scored_at)
    })
  end)

  # Broadcast updates to the UI
  @impl true
  def after_update(_event, _metadata, %{intelligence_analysis: analysis}) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "intelligence:analyses",
      {:analysis_projected, analysis}
    )

    :ok
  end

  def after_update(_event, _metadata, _changes), do: :ok

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} ->
        dt

      {:error, reason} ->
        Logger.error(
          "[AnalysisProjector] Failed to parse datetime: #{inspect(iso8601)}, reason: #{inspect(reason)}"
        )

        nil
    end
  end

  defp parse_datetime(other) do
    Logger.warning("[AnalysisProjector] Unexpected datetime format: #{inspect(other)}")
    nil
  end
end
