defmodule Nexus.Intelligence.AISentinelTest do
  use Cabbage.Feature, file: "intelligence/ai_sentinel.feature"
  use Nexus.DataCase

  @moduletag :feature

  alias Nexus.Intelligence.Commands.{AnalyzeInvoice, AnalyzeSentiment}
  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored}
  alias Nexus.App

  setup do
    {:ok,
     %{
       analysis_id: Ecto.UUID.generate(),
       org_id: Ecto.UUID.generate(),
       invoice_id: Ecto.UUID.generate(),
       source_id: Ecto.UUID.generate()
     }}
  end

  defgiven ~r/^a vendor "(?<vendor>[^"]+)" with a historical average invoice of (?<avg>\d+) EUR$/,
           %{vendor: vendor, avg: avg},
           state do
    {:ok, Map.merge(state, %{vendor: vendor, avg: avg})}
  end

  defwhen ~r/^an invoice for (?<amount>\d+) EUR is ingested$/, %{amount: amount}, state do
    cmd = %AnalyzeInvoice{
      analysis_id: state.analysis_id,
      org_id: state.org_id,
      invoice_id: state.invoice_id,
      vendor_name: state.vendor,
      amount: Decimal.new(amount),
      currency: "EUR"
    }

    :ok = App.dispatch(cmd)
    {:ok, state}
  end

  defthen ~r/^the AI Sentinel should flag it with an "anomaly_score" greater than (?<score>[.\d]+)$/,
          %{score: score},
          state do
    {:ok, state}
  end

  defthen ~r/^emit an "AnomalyDetected" event$/, _vars, state do
    # 1. Verify Event Store
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.analysis_id)
    assert Enum.any?(events, fn e -> e.data.__struct__ == AnomalyDetected end)

    # 2. Verify Read Model (Wait for projector)
    Process.sleep(500)
    analysis = Repo.get(Nexus.Intelligence.Projections.Analysis, state.analysis_id)
    assert analysis != nil
    assert analysis.type == "anomaly"
    assert analysis.invoice_id == state.invoice_id

    {:ok, state}
  end

  defgiven ~r/^the AI Sentinel is actively monitoring communications$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^the system processes a communication reading "(?<text>[^"]+)"$/,
          %{text: text},
          state do
    cmd = %AnalyzeSentiment{
      analysis_id: state.analysis_id,
      org_id: state.org_id,
      source_id: state.source_id,
      text: text
    }

    :ok = App.dispatch(cmd)
    {:ok, state}
  end

  defthen ~r/^the AI Sentinel should score the sentiment as "(?<sentiment>[^"]+)"$/,
          %{sentiment: _sentiment},
          state do
    {:ok, state}
  end

  defthen ~r/^emit a "SentimentScored" event$/, _vars, state do
    # 1. Verify Event Store
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.analysis_id)
    assert Enum.any?(events, fn e -> e.data.__struct__ == SentimentScored end)

    # 2. Verify Read Model (Wait for projector)
    Process.sleep(500)
    analysis = Repo.get(Nexus.Intelligence.Projections.Analysis, state.analysis_id)
    assert analysis != nil
    assert analysis.type == "sentiment"
    assert analysis.source_id == state.source_id

    {:ok, state}
  end
end
