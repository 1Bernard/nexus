defmodule Nexus.Policies.PaymentsPolicyFeatureTest do
  @moduledoc false
  use Cabbage.Feature, file: "policies/payments_policy.feature"
  alias Nexus.Payments.Policies.PaymentsPolicy

  setup do
    {:ok, %{org_id: Nexus.Schema.generate_uuidv7()}}
  end

  # --- Given ---

  defgiven ~r/^a user with role "(?<role>[^"]+)" in the payments context$/, %{role: role}, state do
    user =
      cond do
        role in ["treasury_ops", "system_admin"] -> %{roles: [role], org_id: state.org_id}
        true -> %{role: role, org_id: state.org_id}
      end

    {:ok, Map.put(state, :current_user, user)}
  end

  defgiven ~r/^no authenticated user in the payments context$/, _vars, state do
    {:ok, Map.put(state, :current_user, nil)}
  end

  # --- When ---

  defwhen ~r/^I check if the user can "(?<action>[^"]+)" "payments"$/,
          %{action: action},
          state do
    result = PaymentsPolicy.can?(state.current_user, String.to_atom(action), :payments)
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
