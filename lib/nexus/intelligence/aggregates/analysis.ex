defmodule Nexus.Intelligence.Aggregates.Analysis do
  @moduledoc """
  Aggregate handling intelligence analysis (anomaly detection & sentiment).
  Delegates inference to supervised Bumblebee/Nx services.
  """
  require Logger

  defstruct [:id]

  alias Nexus.Intelligence.Commands.{AnalyzeInvoice, AnalyzeSentiment, ResolveAnomaly}
  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored, AnomalyResolved}

  # For anomaly detection, we only emit an event if it's an anomaly (score > 0.8)
  def execute(%__MODULE__{} = _state, %AnalyzeInvoice{} = cmd) do
    Logger.debug("[AI Sentinel] Executing AnalyzeInvoice for #{cmd.invoice_id}")

    Logger.debug(
      "[AI Sentinel] Analyzing vendor: #{cmd.vendor_name}, amount: #{inspect(cmd.amount)}"
    )

    # Delegate to the ML service
    case Nexus.Intelligence.Services.AnomalyDetector.analyze(cmd) do
      {:ok, %{is_anomaly: true, score: score, reason: reason} = result} ->
        Logger.debug("[AI Sentinel] Anomaly detected: #{inspect(result)}")

        %AnomalyDetected{
          analysis_id: cmd.analysis_id,
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          score: score,
          reason: reason,
          flagged_at: DateTime.utc_now()
        }

      {:ok, %{is_anomaly: false}} ->
        Logger.debug("[AI Sentinel] No anomaly detected for #{cmd.invoice_id}")
        # No anomaly, no state change
        []
    end
  end

  def execute(%__MODULE__{} = _state, %AnalyzeSentiment{} = cmd) do
    Logger.debug("[AI Sentinel] Executing AnalyzeSentiment for #{cmd.analysis_id}")

    case Nexus.Intelligence.Services.SentimentAnalyzer.analyze(cmd.text) do
      {:ok, %{sentiment: sentiment, confidence: confidence} = result} ->
        Logger.debug("[AI Sentinel] Sentiment analyzed: #{inspect(result)}")

        %SentimentScored{
          analysis_id: cmd.analysis_id,
          org_id: cmd.org_id,
          source_id: cmd.source_id,
          sentiment: sentiment,
          confidence: confidence,
          scored_at: DateTime.utc_now()
        }

      other ->
        Logger.error("[AI Sentinel] Sentiment analysis unexpected result: #{inspect(other)}")
        []
    end
  end

  def execute(%__MODULE__{} = _state, %ResolveAnomaly{} = cmd) do
    Logger.debug(
      "[AI Sentinel] Executing ResolveAnomaly for #{cmd.analysis_id} with resolution #{cmd.resolution}"
    )

    %AnomalyResolved{
      analysis_id: cmd.analysis_id,
      resolution: cmd.resolution,
      resolved_at: DateTime.utc_now()
    }
  end

  # Apply functions
  def apply(%__MODULE__{} = state, %AnomalyDetected{analysis_id: id}) do
    %__MODULE__{state | id: id}
  end

  def apply(%__MODULE__{} = state, %SentimentScored{analysis_id: id}) do
    %__MODULE__{state | id: id}
  end

  def apply(%__MODULE__{} = state, %AnomalyResolved{}) do
    # Logical deletion, no state change needed on aggregate
    state
  end
end
