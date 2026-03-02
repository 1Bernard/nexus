defmodule Nexus.Intelligence.Aggregates.Analysis do
  @moduledoc """
  Aggregate handling intelligence analysis (anomaly detection & sentiment).
  Delegates inference to supervised Bumblebee/Nx services.
  """

  defstruct [:id]

  alias Nexus.Intelligence.Commands.{AnalyzeInvoice, AnalyzeSentiment}
  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored}

  # For anomaly detection, we only emit an event if it's an anomaly (score > 0.8)
  def execute(%__MODULE__{} = _state, %AnalyzeInvoice{} = cmd) do
    # Delegate to the ML service
    case Nexus.Intelligence.Services.AnomalyDetector.analyze(cmd) do
      {:ok, %{is_anomaly: true, score: score, reason: reason}} ->
        %AnomalyDetected{
          analysis_id: cmd.analysis_id,
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          score: score,
          reason: reason,
          flagged_at: DateTime.utc_now()
        }

      {:ok, %{is_anomaly: false}} ->
        # No anomaly, no state change
        []

      {:error, _reason} ->
        []
    end
  end

  def execute(%__MODULE__{} = _state, %AnalyzeSentiment{} = cmd) do
    case Nexus.Intelligence.Services.SentimentAnalyzer.analyze(cmd.text) do
      {:ok, %{sentiment: sentiment, confidence: confidence}} ->
        %SentimentScored{
          analysis_id: cmd.analysis_id,
          org_id: cmd.org_id,
          source_id: cmd.source_id,
          sentiment: sentiment,
          confidence: confidence,
          scored_at: DateTime.utc_now()
        }

      {:error, _reason} ->
        []
    end
  end

  # Apply functions
  def apply(%__MODULE__{} = state, %AnomalyDetected{analysis_id: id}) do
    %__MODULE__{state | id: id}
  end

  def apply(%__MODULE__{} = state, %SentimentScored{analysis_id: id}) do
    %__MODULE__{state | id: id}
  end
end
