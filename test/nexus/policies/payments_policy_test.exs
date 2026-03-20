defmodule Nexus.Policies.PaymentsPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Payments.Policies.PaymentsPolicy

  describe "can?/3" do
    test "allows any authenticated user to view payments" do
      user = %{role: "viewer", org_id: "org1"}
      assert PaymentsPolicy.can?(user, :view, :payments)
    end

    test "allows treasury_ops or system_admin to initiate/approve payments" do
      trader = %{role: "treasury_ops", org_id: "org1"}
      admin = %{role: "system_admin", org_id: "org1"}
      viewer = %{role: "viewer", org_id: "org1"}

      assert PaymentsPolicy.can?(trader, :initiate, :payments)
      assert PaymentsPolicy.can?(admin, :approve, :payments)
      refute PaymentsPolicy.can?(viewer, :initiate, :payments)
    end

    test "denies nil user" do
      refute PaymentsPolicy.can?(nil, :initiate, :payments)
    end
  end
end
