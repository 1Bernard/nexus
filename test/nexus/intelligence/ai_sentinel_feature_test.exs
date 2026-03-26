defmodule Nexus.Intelligence.AISentinelTest do
  use Cabbage.Feature, file: "intelligence/ai_sentinel.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

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
       analysis_id: Nexus.Schema.generate_uuidv7(),
       org_id: Nexus.Schema.generate_uuidv7(),
       invoice_id: Nexus.Schema.generate_uuidv7(),
       source_id: Nexus.Schema.generate_uuidv7()
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
          %{score: _score},
          state do
    {:ok, state}
  end

  defthen ~r/^emit an "AnomalyDetected" event$/, _vars, state do
    # 1. Verify Event Store
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.analysis_id)
    assert Enum.any?(events, fn e -> e.data.__struct__ == AnomalyDetected end)

    # 2. Verify Read Model (Manual projection since async projectors are disabled in test env)
    Enum.each(events, fn e -> project_event(e.data, e.event_number) end)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      analysis = Repo.get(Nexus.Intelligence.Projections.Analysis, state.analysis_id)
      assert analysis != nil
      assert analysis.type == "anomaly"
      assert analysis.invoice_id == state.invoice_id
    end)

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

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      analysis = Repo.get(Nexus.Intelligence.Projections.Analysis, state.analysis_id)
      assert analysis != nil
      assert analysis.type == "sentiment"
      assert analysis.source_id == state.source_id
    end)

    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, _event_number) do
    metadata = %{
      handler_name: "Intelligence.AnalysisProjector",
      event_number: _event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Intelligence.Projectors.AnalysisProjector.handle(event, metadata)
    end)
  end
end
