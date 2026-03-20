defmodule Nexus.Policies.ERPPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.ERP.Policies.ERPPolicy

  describe "can?/3" do
    test "allows any authenticated user to view erp" do
      user = %{role: "viewer", org_id: "org1"}
      assert ERPPolicy.can?(user, :view, :erp)
    end

    test "denies nil user" do
      refute ERPPolicy.can?(nil, :view, :erp)
    end
  end
end
