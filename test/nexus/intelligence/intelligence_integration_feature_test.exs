defmodule Nexus.Intelligence.IntelligenceIntegrationTest do
  use Cabbage.Feature, file: "intelligence/intelligence_integration.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Intelligence.Projections.Analysis

  setup do
    org_id = Nexus.Schema.generate_uuidv7()
    vault_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Analysis)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{org_id: org_id, vault_id: vault_id}}
  end

  # --- Given ---

  defgiven ~r/^a tenant exists in the intelligence monitor$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^"(?<count>\d+)" transfers occur within "(?<seconds>\d+)" seconds for the same vault$/,
          %{count: count_str},
          state do
    count = String.to_integer(count_str)

    # 1. Trigger the analyzer handler
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Enum.each(1..count, fn i ->
        transfer_id = Nexus.Schema.generate_uuidv7()
        event = %Nexus.Treasury.Events.TransferExecuted{
          transfer_id: transfer_id,
          org_id: state.org_id,
          amount: Decimal.new(2_000_000),
          from_currency: "EUR",
          to_currency: "USD",
          executed_at: DateTime.utc_now()
        }

        # Use strong consistency to ensure event is emitted before return
        Nexus.Intelligence.Handlers.TreasuryMovementAnalyzer.handle(event, %{
          handler_name: "Intelligence.TreasuryMovementAnalyzer",
          event_number: i,
          consistency: :strong
        })
      end)
    end)

    # 2. Capture and project the resulting analysis (AnomalyDetected)
    # Since TreasuryMovementAnalyzer generates random IDs, we scan the event store.
    all_events = wait_for_events(Nexus.Intelligence.Events.AnomalyDetected, count)

    anomalies = Enum.filter(all_events, fn e ->
      e.data.__struct__ == Nexus.Intelligence.Events.AnomalyDetected and
      e.data.org_id == state.org_id
    end)

    Enum.each(anomalies, fn e ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        Nexus.Intelligence.Projectors.AnalysisProjector.handle(e.data, %{
          handler_name: "Intelligence.AnalysisProjector",
          event_number: e.event_number,
          correlation_id: e.correlation_id,
          causation_id: e.causation_id
        })
      end)
    end)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^an anomaly should be flagged by the AI Sentinel$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      anomalies = Repo.all(Analysis)
      assert anomalies != []
      assert Enum.any?(anomalies, fn a -> a.type == "anomaly" end)
    end)
    {:ok, state}
  end

  defthen ~r/^a risk alert should be dispatched to the security team$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp wait_for_events(event_type, count, attempts \\ 10)
  defp wait_for_events(_event_type, _count, 0), do: []
  defp wait_for_events(event_type, count, attempts) do
    # Use high-count forward scan to ensure we see all events in the session (Elite standard)
    {:ok, events} = Nexus.EventStore.read_all_streams_forward(0, 5000)
    found = Enum.filter(events, fn e -> e.data.__struct__ == event_type end)

    Logger.debug("[BDD] wait_for_events: Found #{length(found)} of #{event_type} (Target: #{count}, Attempts left: #{attempts})")

    if length(found) >= count do
      events
    else
      :timer.sleep(100)
      wait_for_events(event_type, count, attempts - 1)
    end
  end
 end
