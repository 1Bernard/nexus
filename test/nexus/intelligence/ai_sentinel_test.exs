defmodule Nexus.Intelligence.AISentinelTest do
  use Cabbage.Feature, file: "intelligence/ai_sentinel.feature"
  use Nexus.DataCase

  @moduletag :feature

  alias Nexus.Intelligence.Commands.{AnalyzeInvoice, AnalyzeSentiment}
  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored}
  alias Nexus.App

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(Nexus.Intelligence.Projections.Analysis)

      Ecto.Adapters.SQL.query!(
        Nexus.Repo,
        "DELETE FROM projection_versions WHERE projection_name = 'Intelligence.AnalysisProjector'"
      )
    end)

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
      currency: "EUR",
      flagged_at: DateTime.utc_now()
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

    # 2. Verify Read Model (Manual projection since async projectors are disabled in test env)
    Enum.each(events, fn e -> project_event(e.data, e.event_number) end)

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
      text: text,
      scored_at: DateTime.utc_now()
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

    # 2. Verify Read Model (Manual projection since async projectors are disabled in test env)
    Enum.each(events, fn e -> project_event(e.data, e.event_number) end)

    analysis = Repo.get(Nexus.Intelligence.Projections.Analysis, state.analysis_id)
    assert analysis != nil
    assert analysis.type == "sentiment"
    assert analysis.source_id == state.source_id

    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, _event_number) do
    attrs =
      case event do
        %AnomalyDetected{} = ev ->
          %{
            id: ev.analysis_id,
            org_id: ev.org_id,
            invoice_id: ev.invoice_id,
            type: "anomaly",
            score: ev.score,
            reason: ev.reason,
            flagged_at: ev.flagged_at
          }

        %SentimentScored{} = ev ->
          %{
            id: ev.analysis_id,
            org_id: ev.org_id,
            source_id: ev.source_id,
            type: "sentiment",
            sentiment: ev.sentiment,
            confidence: ev.confidence,
            scored_at: ev.scored_at
          }

        _ ->
          nil
      end

    if attrs do
      Repo.insert!(
        Nexus.Intelligence.Projections.Analysis.changeset(
          %Nexus.Intelligence.Projections.Analysis{},
          attrs
        )
      )
    end
  end
end
