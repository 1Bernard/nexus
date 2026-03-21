defmodule Nexus.Intelligence.IntelligenceIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Repo
  alias Nexus.Intelligence.Projections.Analysis
  alias Nexus.Treasury.Events.{TransferExecuted, ReconciliationProposed}
  alias Nexus.App
  require Logger

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Analysis)
      :ok
    end)

    org_id = Nexus.Schema.generate_uuidv7()

    # Start the projectors and handlers needed for this test
    # These will run outside the sandbox if unboxed_run was used effectively,
    # or they'll be managed by the test's supervisor.
    start_supervised!(Nexus.Intelligence.Projectors.AnalysisProjector)
    start_supervised!(Nexus.Intelligence.Handlers.TreasuryMovementAnalyzer)
    start_supervised!(Nexus.Intelligence.Handlers.ReconciliationAnalyzer)

    {:ok, %{org_id: org_id}}
  end

  test "detects anomalous treasury movement when a large transfer is executed", %{org_id: org_id} do
    transfer_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    # In test mode, AnomalyDetector flags > 1M as anomaly
    event = %TransferExecuted{
      transfer_id: transfer_id,
      org_id: org_id,
      amount: "1500000", # 1.5M
      from_currency: "USD",
      to_currency: "EUR",
      executed_at: DateTime.utc_now()
    }

    # Dispatch directly to the aggregate
    analysis_id = Nexus.Schema.generate_uuidv7()
    command = %Nexus.Intelligence.Commands.AnalyzeTreasuryMovement{
      analysis_id: analysis_id,
      org_id: org_id,
      transfer_id: transfer_id,
      amount: Decimal.new("1500000"),
      currency: "USD",
      flagged_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Wait for projection
    assert_eventually_projected(transfer_id, :treasury_movement)

    analysis = Repo.get_by(Analysis, source_id: transfer_id)
    assert analysis != nil
    assert analysis.type == "anomaly"
    assert analysis.score > 0.9
    assert analysis.reason =~ "High-value"
  end

  test "detects anomaly for high-variance reconciliation", %{org_id: org_id} do
    reconciliation_id = Nexus.Schema.generate_uuidv7()

    # In AnomalyDetector, variance > 1000 is flagged
    event = %ReconciliationProposed{
      reconciliation_id: reconciliation_id,
      org_id: org_id,
      statement_line_id: Nexus.Schema.generate_uuidv7(),
      invoice_id: Nexus.Schema.generate_uuidv7(),
      amount: Decimal.new("5000"),
      variance: Decimal.new("1500"),
      currency: "USD",
      timestamp: DateTime.utc_now()
    }

    :ok = Nexus.Intelligence.Handlers.ReconciliationAnalyzer.handle(event, %{})

    assert_eventually_projected(reconciliation_id, :reconciliation)

    analysis = Repo.get_by(Analysis, source_id: reconciliation_id)
    assert analysis != nil
    assert analysis.type == "anomaly"
    assert analysis.reason =~ "High-variance"
  end

  defp assert_eventually_projected(source_id, _type, attempts \\ 30)
  defp assert_eventually_projected(source_id, _type, 0) do
    flunk("Analysis for source_id #{source_id} not projected in time")
  end
  defp assert_eventually_projected(source_id, type, attempts) do
    if Repo.get_by(Analysis, source_id: source_id) do
      :ok
    else
      Process.sleep(100)
      assert_eventually_projected(source_id, type, attempts - 1)
    end
  end
end
