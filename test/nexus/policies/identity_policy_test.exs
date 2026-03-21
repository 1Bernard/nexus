defmodule Nexus.Policies.IdentityPolicyTest do
  use ExUnit.Case, async: true
  alias Nexus.Identity.Policies.IdentityPolicy

  describe "can?/3" do
    test "allows only system_admin for backoffice" do
      sys_admin = %{roles: ["system_admin"], org_id: "org1"}
      org_admin = %{role: "org_admin", org_id: "org1"}

      assert IdentityPolicy.can?(sys_admin, :access, :backoffice)
      refute IdentityPolicy.can?(org_admin, :access, :backoffice)
    end
  end
end
