defmodule Nexus.Intelligence.Projectors.AnalysisProjector do
  @moduledoc """
  Listens for anomaly, sentiment, and settlement events and writes analysis records
  to the intelligence_analyses table.
  """
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
    amount_str =
      event.amount
      |> Decimal.to_float()
      |> :erlang.float_to_binary(decimals: 2)

    attrs = %{
      id: event.statement_line_id,
      org_id: event.org_id,
      source_id: event.statement_line_id,
      type: "anomaly",
      score: 1.0,
      reason: "Reconciliation Failure: #{event.reason} (#{amount_str} #{event.currency})",
      flagged_at: Nexus.Schema.parse_datetime(event.timestamp)
    }

    Ecto.Multi.insert(multi, :intelligence_analysis, Analysis.changeset(%Analysis{}, attrs))
  end)

  project(%SentimentScored{} = event, _metadata, fn multi ->
    reason =
      cond do
        event.sentiment == "positive" and event.confidence > 0.9 ->
          "Strong positive alignment. Vendor communication indicates optimal operational synergy."

        event.sentiment == "positive" ->
          "Communication pattern aligns with historical trajectory. No immediate escalation needed."

        event.sentiment == "negative" and event.confidence > 0.8 ->
          "Critical sentiment deviation. Urgent tone detected in vendor stream—requires immediate oversight."

        event.sentiment == "negative" ->
          "Subtle friction detected. Sentiment profile suggests potential friction in upcoming settlement cycle."

        true ->
          "Neutral communication baseline maintained across inbound vendor streams."
      end

    attrs = %{
      id: event.analysis_id,
      org_id: event.org_id,
      source_id: event.source_id,
      type: "sentiment",
      sentiment: event.sentiment,
      confidence: event.confidence,
      reason: reason,
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
