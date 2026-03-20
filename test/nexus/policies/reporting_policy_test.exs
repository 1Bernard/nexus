defmodule Nexus.Policies.ReportingPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Reporting.Policies.ReportingPolicy

  describe "can?/3" do
    test "allows auditor and system_admin for audit_logs" do
      auditor = %{role: "auditor", org_id: "org1"}
      sys_admin = %{role: "system_admin", org_id: "org1"}
      trader = %{role: "trader", org_id: "org1"}

      assert ReportingPolicy.can?(auditor, :view, :audit_logs)
      assert ReportingPolicy.can?(sys_admin, :view, :audit_logs)
      refute ReportingPolicy.can?(trader, :view, :audit_logs)
    end

    test "denies nil user" do
      refute ReportingPolicy.can?(nil, :view, :audit_logs)
    end
  end
end
