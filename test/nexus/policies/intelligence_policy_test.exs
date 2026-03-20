defmodule Nexus.Policies.IntelligencePolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Intelligence.Policies.IntelligencePolicy

  describe "can?/3" do
    test "allows auditor and system_admin for compliance" do
      auditor = %{role: "auditor", org_id: "org1"}
      sys_admin = %{role: "system_admin", org_id: "org1"}
      trader = %{role: "trader", org_id: "org1"}

      assert IntelligencePolicy.can?(auditor, :view, :compliance)
      assert IntelligencePolicy.can?(sys_admin, :view, :compliance)
      refute IntelligencePolicy.can?(trader, :view, :compliance)
    end

    test "denies nil user" do
      refute IntelligencePolicy.can?(nil, :view, :compliance)
    end
  end
end
