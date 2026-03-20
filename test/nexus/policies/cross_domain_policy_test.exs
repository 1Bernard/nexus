defmodule Nexus.Policies.CrossDomainPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.CrossDomain.Policies.CrossDomainPolicy

  describe "can?/3" do
    test "allows any authenticated user for notifications" do
      user = %{role: "viewer", org_id: "org1"}
      assert CrossDomainPolicy.can?(user, :view, :notifications)
    end

    test "denies nil user" do
      refute CrossDomainPolicy.can?(nil, :view, :notifications)
    end
  end
end
