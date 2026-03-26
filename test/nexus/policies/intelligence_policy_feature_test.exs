defmodule Nexus.Policies.IntelligencePolicyFeatureTest do
  use Cabbage.Feature, file: "policies/intelligence_policy.feature"
  alias Nexus.Intelligence.Policies.IntelligencePolicy

  setup do
    {:ok, %{}}
  end

  # --- Given ---

  defgiven ~r/^a user with role "(?<role>[^"]+)" in the intelligence context$/, %{role: role}, state do
    user = %{roles: [role], org_id: "org1"}
    {:ok, Map.put(state, :user, user)}
  end

  defgiven ~r/^no authenticated user in the intelligence context$/, _vars, state do
    {:ok, Map.put(state, :user, nil)}
  end

  # --- When ---

  defwhen ~r/^I check if the user can "(?<action>[^"]+)" "(?<resource>[^"]+)"$/,
          %{action: action, resource: resource},
          state do
    res = IntelligencePolicy.can?(state.user, String.to_atom(action), String.to_atom(resource))
    {:ok, Map.put(state, :can_result, res)}
  end

  # --- Then ---

  defthen ~r/^the action should be allowed$/, _vars, state do
    assert state.can_result == true
    {:ok, state}
  end

  defthen ~r/^the action should be denied$/, _vars, state do
    assert state.can_result == false
    {:ok, state}
  end
end
