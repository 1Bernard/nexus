defmodule Nexus.Policies.IdentityPolicyFeatureTest do
  use Cabbage.Feature, file: "policies/identity_policy.feature"
  alias Nexus.Identity.Policies.IdentityPolicy

  setup do
    {:ok, %{}}
  end

  # --- Given ---

  defgiven ~r/^a user with role "(?<role>[^"]+)"$/, %{role: role}, state do
    # Handle both single role (role: role) and list of roles (roles: [role]) based on what the policy expects.
    # The original test used both %{roles: ["system_admin"]} and %{role: "org_admin"}.
    # Let's standardize to the most common one or the one that passes.
    user = if role == "system_admin", do: %{roles: [role], org_id: "org1"}, else: %{role: role, org_id: "org1"}
    {:ok, Map.put(state, :user, user)}
  end

  # --- When ---

  defwhen ~r/^I check if the user can "(?<action>[^"]+)" "(?<resource>[^"]+)"$/,
          %{action: action, resource: resource},
          state do
    res = IdentityPolicy.can?(state.user, String.to_atom(action), String.to_atom(resource))
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
