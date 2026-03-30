defmodule Nexus.Reporting.SoDFeatureTest do
  @moduledoc """
  Elite BDD tests for Segregation of Duties logic.
  Standardized to Cabbage Gherkin format.
  """
  use Cabbage.Feature, file: "reporting/sod_feature.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Reporting
  alias Nexus.Identity.Projections.User

  setup do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, org_id: org_id}
  end

  # --- Gherkin Steps ---

  defgiven ~r/^an organization exists in the Nexus ecosystem$/, _, state do
    # org_id is already in state from setup
    {:ok, state}
  end

  defwhen ~r/^a user is assigned the "(?<role>[^"]+)" role$/, %{role: role}, %{org_id: org_id} = state do
    insert_user(org_id, [role])
    {:ok, state}
  end

  defwhen ~r/^another user is assigned the "(?<role>[^"]+)" role$/, %{role: role}, %{org_id: org_id} = state do
    insert_user(org_id, [role])
    {:ok, state}
  end

  defgiven ~r/assign the "(?<role1>[^"]+)" and "(?<role2>[^"]+)" roles to a user/, %{role1: r1, role2: r2}, %{org_id: org_id} = state do
    user = insert_user(org_id, [r1, r2])
    new_state = Map.put(state, :target_user, user)
    {:ok, new_state}
  end

  defwhen ~r/^a toxic role combination is assigned to a user in a different organization$/, _, %{org_id: _org_id} = state do
    other_org = Nexus.Schema.generate_uuidv7()
    insert_user(other_org, ["trader", "admin"])
    {:ok, state}
  end

  defthen ~r/^the SoD conflict report should be empty$/, _, %{org_id: org_id} = state do
    unboxed_run(fn ->
      assert Reporting.list_sod_conflicts(org_id) == []
    end)
    {:ok, state}
  end

  defthen ~r/^an "(?<type>[^"]+)" conflict should be flagged with "(?<severity>[^"]+)" severity$/, %{type: type, severity: severity}, %{org_id: org_id, target_user: user} = state do
    unboxed_run(fn ->
      conflicts = Reporting.list_sod_conflicts(org_id)
      conflict = Enum.find(conflicts, &(&1.conflict_type =~ type and &1.user_id == user.id))

      assert conflict, "Expected conflict of type '#{type}' to be flagged"
      assert conflict.severity == severity
    end)
    {:ok, state}
  end

  defthen ~r/^an "(?<type>[^"]+)" conflict should also be flagged$/, %{type: type}, %{org_id: org_id, target_user: user} = state do
    unboxed_run(fn ->
      conflicts = Reporting.list_sod_conflicts(org_id)
      assert Enum.any?(conflicts, &(&1.conflict_type =~ type and &1.user_id == user.id))
    end)
    {:ok, state}
  end

  defthen ~r/^the SoD conflict report for the current organization should remain empty$/, _, %{org_id: org_id} = state do
    unboxed_run(fn ->
      assert Reporting.list_sod_conflicts(org_id) == []
    end)
    {:ok, state}
  end

  # --- Helpers ---

  defp insert_user(org_id, roles) do
    unboxed_run(fn ->
      Repo.insert!(%User{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: org_id,
        email: "user_#{Nexus.Schema.generate_uuidv7()}@nexus.xyz",
        display_name: "Test User",
        roles: roles,
        status: "active",
        cose_key: <<0>>,
        credential_id: Nexus.Schema.generate_uuidv7()
      })
    end)
  end
end
