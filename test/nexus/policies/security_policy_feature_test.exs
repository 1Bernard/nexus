defmodule Nexus.Policies.SecurityPolicyFeatureTest do
  @moduledoc """
  Elite BDD tests for Cross-Domain Security Policies.
  Standardized to Cabbage Gherkin format.
  """
  use Cabbage.Feature, file: "policies/security_policy.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.CrossDomain.Policies.CrossDomainPolicy

  setup do
    {:ok, %{}}
  end

  # --- Gherkin Steps ---

  defgiven ~r/^an authenticated user with "(?<role>[^"]+)" role$/, %{role: role}, state do
    user = %{role: role, org_id: "org1"}
    {:ok, Map.put(state, :user, user)}
  end

  defwhen ~r/^they attempt to view notifications$/, _, %{user: user} = state do
    result = CrossDomainPolicy.can?(user, :view, :notifications)
    {:ok, Map.put(state, :result, result)}
  end

  defgiven ~r/^an unauthenticated user attempts to view notifications$/, _, state do
    result = CrossDomainPolicy.can?(nil, :view, :notifications)
    {:ok, Map.put(state, :result, result)}
  end

  defthen ~r/^the action should be allowed$/, _, %{result: result} = state do
    assert result == true
    {:ok, state}
  end

  defthen ~r/^the action should be denied$/, _, %{result: result} = state do
    assert result == false
    {:ok, state}
  end
end
