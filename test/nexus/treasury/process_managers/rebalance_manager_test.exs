defmodule Nexus.Treasury.ProcessManagers.RebalanceManagerTest do
  use ExUnit.Case, async: true
  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated

  # Note: This test would usually require a Vault in the DB since handle/2 calls VaultQuery.
  # For a pure unit test, we'd refactor the Saga to accept a dependency or simulate the environment.
  # Here, we'll test the core logic of forecast parsing.

  describe "handle/2" do
    test "ignores positive forecasts" do
      event = %ForecastGenerated{
        org_id: "org1",
        currency: "USD",
        horizon_days: 7,
        predictions: [%{amount: Decimal.new(1000)}],
        generated_at: DateTime.utc_now()
      }

      assert RebalanceManager.handle(%RebalanceManager{}, event) == []
    end

    # To test the Rebalance dispatch, we'd normally need a RebalanceManager.execute or similar.
    # Given the current implementation, it will attempt to query the DB.
    # We'll skip the DB-dependent part in a pure unit test or use a real integration test.
  end

  describe "apply/2" do
    test "transitions state on ForecastGenerated" do
      event = %ForecastGenerated{
        org_id: "org1",
        currency: "USD",
        horizon_days: 7,
        predictions: [],
        generated_at: DateTime.utc_now()
      }
      state = RebalanceManager.apply(%RebalanceManager{}, event)
      assert state.org_id == "org1"
      assert state.target_currency == "USD"
    end

    test "marks saga completed on TransferInitiated" do
      event = %Nexus.Treasury.Events.TransferInitiated{
        transfer_id: "tx123",
        org_id: "org1",
        user_id: "user1",
        from_currency: "EUR",
        to_currency: "USD",
        amount: "1000",
        status: "pending_authorization",
        requested_at: DateTime.utc_now()
      }
      state = RebalanceManager.apply(%RebalanceManager{}, event)
      assert state.completed == true
    end
  end

  describe "stop?/1" do
    test "returns true when completed is true" do
      assert RebalanceManager.stop?(%RebalanceManager{completed: true})
    end

    test "returns false when completed is false" do
      refute RebalanceManager.stop?(%RebalanceManager{completed: false})
      refute RebalanceManager.stop?(%RebalanceManager{completed: nil})
    end
  end
end
