defmodule Nexus.Reporting.SoDLogicTest do
  use Nexus.DataCase, async: true

  alias Nexus.Reporting
  alias Nexus.Identity.Projections.User

  describe "list_sod_conflicts/1" do
    setup do
      org_id = Ecto.UUID.generate()
      {:ok, org_id: org_id}
    end

    test "identifies no conflicts for users with single roles", %{org_id: org_id} do
      # Given a trader
      insert_user(org_id, ["trader"])
      # And an approver
      insert_user(org_id, ["approver"])
      # And an admin
      insert_user(org_id, ["admin"])

      assert Reporting.list_sod_conflicts(org_id) == []
    end

    test "flags 'Initiate + Authorize' conflict (trader + approver)", %{org_id: org_id} do
      user = insert_user(org_id, ["trader", "approver"], "toxic@nexus.xyz")

      conflicts = Reporting.list_sod_conflicts(org_id)
      assert length(conflicts) == 1

      conflict = List.first(conflicts)
      assert conflict.user_id == user.id
      assert conflict.conflict_type == "Toxic Combination: Initiate + Authorize"
      assert conflict.severity == "High"
    end

    test "flags 'Initiate + Policy' conflict (trader + admin)", %{org_id: org_id} do
      user = insert_user(org_id, ["trader", "admin"], "policy_toxic@nexus.xyz")

      conflicts = Reporting.list_sod_conflicts(org_id)
      # This user has BOTH Initiate+Authorize (since admin implies authorize) AND Initiate+Policy
      assert length(conflicts) == 2

      types = Enum.map(conflicts, & &1.conflict_type)
      assert "Toxic Combination: Initiate + Authorize" in types
      assert "Toxic Combination: Initiate + Policy" in types
    end

    test "flags 'Authorize + Policy' conflict (approver + admin)", %{org_id: org_id} do
      user = insert_user(org_id, ["approver", "admin"], "admin_toxic@nexus.xyz")

      conflicts = Reporting.list_sod_conflicts(org_id)
      assert length(conflicts) == 1

      conflict = List.first(conflicts)
      assert conflict.user_id == user.id
      assert conflict.conflict_type == "Toxic Combination: Authorize + Policy"
      assert conflict.severity == "Medium"
    end

    test "is strictly scoped by organization", %{org_id: org_id} do
      other_org = Ecto.UUID.generate()
      insert_user(other_org, ["trader", "admin"], "other@nexus.xyz")

      assert Reporting.list_sod_conflicts(org_id) == []
    end
  end

  # --- Helpers ---

  defp insert_user(org_id, roles, email \\ nil) do
    email = email || "user_#{Ecto.UUID.generate()}@nexus.xyz"

    Repo.insert!(%User{
      id: Ecto.UUID.generate(),
      org_id: org_id,
      email: email,
      display_name: "Test User",
      roles: roles,
      status: "active",
      cose_key: <<0>>,
      credential_id: Ecto.UUID.generate()
    })
  end
end
