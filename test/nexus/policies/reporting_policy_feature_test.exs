defmodule Nexus.Policies.ReportingPolicyFeatureTest do
  @moduledoc false
  use Cabbage.Feature, file: "policies/reporting_policy.feature"
  alias Nexus.Reporting.Policies.ReportingPolicy

  setup do
    {:ok, %{org_id: Nexus.Schema.generate_uuidv7()}}
  end

  # --- Given ---

  defgiven ~r/^a user with role "(?<role>[^"]+)" in the reporting context$/, %{role: role}, state do
    user = %{roles: [role], org_id: state.org_id}
    {:ok, Map.put(state, :current_user, user)}
  end

  defgiven ~r/^no authenticated user in the reporting context$/, _vars, state do
    {:ok, Map.put(state, :current_user, nil)}
  end

  # --- When ---

  defwhen ~r/^I check if the user can "(?<action>[^"]+)" "(?<resource>[^"]+)"$/,
          %{action: action, resource: resource},
          state do
    result = ReportingPolicy.can?(state.current_user, String.to_atom(action), String.to_atom(resource))
    {:ok, Map.put(state, :auth_result, result)}
  end

  # --- Then ---

  defthen ~r/^the action should be "allowed"$/, _vars, state do
    assert state.auth_result == true
    {:ok, state}
  end

  defthen ~r/^the action should be "denied"$/, _vars, state do
    assert state.auth_result == false
    {:ok, state}
  end
end
