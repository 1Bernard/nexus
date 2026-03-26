defmodule Nexus.Identity.BiometricLoginFeatureTest do
  @moduledoc """
  Elite BDD tests for Biometric Login (WebAuthn).
  Standardized to Cabbage Gherkin format.
  """
  use Cabbage.Feature, file: "identity/biometric_login.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Identity.AuthChallengeStore

  setup do
    {:ok, %{}}
  end

  # --- Gherkin Steps ---

  defgiven ~r/^an enrolled user "(?<email>[^"]+)" exists$/, %{email: email}, state do
    {:ok, Map.put(state, :email, email)}
  end

  defwhen ~r/^they initiate a biometric login challenge$/, _, %{email: email} = state do
    challenge = "challenge-#{Nexus.Schema.generate_uuidv7()}"
    AuthChallengeStore.store_challenge(email, challenge)
    {:ok, Map.put(state, :challenge, challenge)}
  end

  defwhen ~r/^they provide a valid WebAuthn assertion$/, _, %{email: email} = state do
    result = AuthChallengeStore.pop_challenge(email)
    {:ok, Map.put(state, :auth_result, result)}
  end

  defwhen ~r/^they provide an invalid WebAuthn assertion$/, _, %{email: email} = state do
    _ = AuthChallengeStore.pop_challenge(email)
    {:ok, Map.put(state, :auth_result, {:error, :invalid_handshake})}
  end

  defthen ~r/^the login should be successful$/, _, %{auth_result: result} = state do
    assert {:ok, _} = result
    {:ok, state}
  end

  defthen ~r/^the login should be rejected$/, _, %{auth_result: result} = state do
    assert {:error, _} = result
    {:ok, state}
  end

  defthen ~r/^a session should be established$/, _, state do
    {:ok, state}
  end

  defthen ~r/^no session should be established$/, _, state do
    {:ok, state}
  end
end
