defmodule Nexus.Policies.TreasuryPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Treasury.Policies.TreasuryPolicy

  describe "can?/3" do
    test "returns false for nil user" do
      refute TreasuryPolicy.can?(nil, :any, :any)
    end

    test "allows treasury_ops or system_admin for vault actions" do
      trader = %{roles: ["treasury_ops"], org_id: "org1"}
      admin = %{roles: ["system_admin"], org_id: "org1"}
      viewer = %{role: "viewer", org_id: "org1"}

      assert TreasuryPolicy.can?(trader, :register_vault, :vault)
      assert TreasuryPolicy.can?(admin, :simulate_rebalance, :vault)
      refute TreasuryPolicy.can?(viewer, :register_vault, :vault)
    end

    test "allows treasury_ops for reconciliation actions" do
      trader = %{roles: ["treasury_ops"], org_id: "org1"}
      assert TreasuryPolicy.can?(trader, :confirm, :reconciliation)
      assert TreasuryPolicy.can?(trader, :approve, :reconciliation)
    end
  end
end
