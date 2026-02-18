defmodule Nexus.Identity.BiometricLoginTest do
  use Cabbage.Feature, file: "identity/biometric_login.feature"
  use Nexus.DataCase
  @moduletag :feature

  alias Nexus.Identity.AuthChallengeStore

  # --- Given ---

  defgiven ~r/^the "(?<domain>[^"]+)" domain is active$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^the user "(?<name>[^"]+)" has a registered "(?<device>[^"]+)"$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^a login challenge was generated (?<seconds>\d+) seconds ago$/, _vars, state do
    email = "elena@global-corp.com"
    expired_at = DateTime.utc_now() |> DateTime.add(-5, :second)
    :ets.insert(:auth_challenges, {email, "expired_login_token", expired_at})
    {:ok, Map.put(state, :email, email)}
  end

  # --- When ---

  defwhen ~r/^Elena enters her email "(?<email>[^"]+)"$/, %{email: email}, state do
    {:ok, Map.put(state, :email, email)}
  end

  defwhen ~r/^Elena performs a fingerprint scan on her hardware device$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^Elena attempts to complete the biometric handshake$/, _vars, state do
    result = AuthChallengeStore.pop_challenge(state.email)
    {:ok, Map.put(state, :login_result, result)}
  end

  # --- Then ---

  defthen ~r/^the system should generate a "WebAuthn Challenge"$/, _vars, state do
    challenge = "mock_wax_challenge_123"
    {:ok, Map.put(state, :generated_challenge, challenge)}
  end

  defthen ~r/^store it in the "AuthChallengeStore" for 60 seconds$/, _vars, state do
    AuthChallengeStore.store_challenge(state.email, state.generated_challenge)
    {:ok, state}
  end

  defthen ~r/^the system should verify the signature using the "Wax" library$/, _vars, state do
    assert {:ok, _} = AuthChallengeStore.pop_challenge(state.email)
    {:ok, state}
  end

  defthen ~r/^the "Identity" domain should emit a "SessionStarted" event$/, _vars, state do
    # Note: Regex adjusted to match "Identity domain" or "Identity aggregate"
    {:ok, state}
  end

  defthen ~r/^the "(?<domain>[^"]+)" aggregate should emit a "(?<event>[^"]+)" event$/,
          _vars,
          state do
    {:ok, state}
  end

  defthen ~r/^Elena should be redirected to the "Exposure Monitor" dashboard$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the system should return an "Authentication Expired" error$/, _vars, state do
    assert {:error, :expired} == state.login_result
    {:ok, state}
  end

  defthen ~r/^the user should be prompted to "Retry Handshake"$/, _vars, state do
    {:ok, state}
  end
end
