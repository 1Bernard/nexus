defmodule Nexus.Intelligence.Services.AnomalyDetectorTest do
  use ExUnit.Case, async: true
  alias Nexus.Intelligence.Services.AnomalyDetector
  alias Nexus.Intelligence.Commands.AnalyzeInvoice

  describe "analyze/1" do
    test "detects anomaly for CorpTech exceeding threshold" do
      # In test environment, the detector forces deterministic results
      command = %AnalyzeInvoice{
        analysis_id: Nexus.Schema.generate_uuidv7(),
        org_id: Nexus.Schema.generate_uuidv7(),
        invoice_id: "INV-TEST-001",
        vendor_name: "CorpTech",
        amount: Decimal.new("2500.00"),
        currency: "EUR",
        flagged_at: DateTime.utc_now()
      }

      assert {:ok, result} = AnomalyDetector.analyze(command)
      assert result.is_anomaly == true
      assert result.score == 0.95
      assert result.reason == "Test Anomaly"
    end

    test "does not detect anomaly for normal invoice" do
      command = %AnalyzeInvoice{
        analysis_id: Nexus.Schema.generate_uuidv7(),
        org_id: Nexus.Schema.generate_uuidv7(),
        invoice_id: "INV-TEST-002",
        vendor_name: "Generic Vendor",
        amount: Decimal.new("100.00"),
        currency: "EUR",
        flagged_at: DateTime.utc_now()
      }

      assert {:ok, result} = AnomalyDetector.analyze(command)
      assert result.is_anomaly == false
    end
  end
end
