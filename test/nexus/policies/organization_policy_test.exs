defmodule Nexus.Policies.OrganizationPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Organization.Policies.OrganizationPolicy

  describe "can?/3" do
    test "allows org_admin or system_admin for org_management" do
      org_admin = %{role: "org_admin", org_id: "org1"}
      sys_admin = %{role: "system_admin", org_id: "org1"}
      trader = %{role: "trader", org_id: "org1"}

      assert OrganizationPolicy.can?(org_admin, :edit, :org_management)
      assert OrganizationPolicy.can?(sys_admin, :view, :org_management)
      refute OrganizationPolicy.can?(trader, :edit, :org_management)
    end

    test "denies nil user" do
      refute OrganizationPolicy.can?(nil, :view, :org_management)
    end
  end
end
