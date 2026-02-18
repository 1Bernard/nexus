defmodule Nexus.Identity.IdentityChallengeStoreTest do
  use Cabbage.Feature, file: "identity/identity_challenge_store.feature"
  use Nexus.DataCase
  @moduletag :feature

  alias Nexus.Identity.AuthChallengeStore

  # --- Given ---

  defgiven ~r/^the Identity Challenge Store is "(?<status>[^"]+)"$/, %{status: _s}, state do
    {:ok, Map.put(state, :store_pid, Process.whereis(AuthChallengeStore))}
  end

  defgiven ~r/^a secure session "(?<session_id>[^"]+)" has been established$/,
           %{session_id: session_id},
           state do
    {:ok, Map.put(state, :session_id, session_id)}
  end

  defgiven ~r/^a stored challenge "(?<challenge>[^"]+)" exists for "(?<session_id>[^"]+)"$/,
           %{challenge: challenge, session_id: session_id},
           state do
    AuthChallengeStore.store_challenge(session_id, challenge)
    {:ok, Map.merge(state, %{session_id: session_id, challenge: challenge})}
  end

  defgiven ~r/^"(?<seconds>\d+)" seconds have passed$/, _vars, state do
    expired_at = DateTime.utc_now() |> DateTime.add(-1, :second)
    :ets.insert(:auth_challenges, {state.session_id, "expired_token", expired_at})
    {:ok, state}
  end

  # --- When ---

  defwhen ~r/^the system generates a challenge "(?<challenge>[^"]+)" for "(?<session_id>[^"]+)"$/,
          %{challenge: challenge, session_id: session_id},
          state do
    AuthChallengeStore.store_challenge(session_id, challenge)
    {:ok, Map.put(state, :last_challenge, challenge)}
  end

  defwhen ~r/^the user retrieves the challenge for verification$/, _vars, state do
    result = AuthChallengeStore.pop_challenge(state.session_id)
    {:ok, Map.put(state, :pop_result, result)}
  end

  defwhen ~r/^the user attempts to retrieve the challenge$/, _vars, state do
    result = AuthChallengeStore.pop_challenge(state.session_id)
    {:ok, Map.put(state, :pop_result, result)}
  end

  # --- Then ---

  defthen ~r/^the challenge should be stored in the in-memory "ETS" cache$/, _vars, state do
    session_id = state.session_id
    last_challenge = state.last_challenge
    assert [{^session_id, ^last_challenge, _}] = :ets.lookup(:auth_challenges, session_id)
    {:ok, state}
  end

  defthen ~r/^it should be available for retrieval for "(?<seconds>\d+)" seconds$/,
          _vars,
          state do
    [{_, _, expiry}] = :ets.lookup(:auth_challenges, state.session_id)
    assert DateTime.compare(expiry, DateTime.utc_now()) == :gt
    {:ok, state}
  end

  defthen ~r/^the system should return "(?<challenge>[^"]+)"$/, %{challenge: expected}, state do
    assert {:ok, ^expected} = state.pop_result
    {:ok, state}
  end

  defthen ~r/^the challenge should be "immediately deleted" from the cache$/, _vars, state do
    assert [] == :ets.lookup(:auth_challenges, state.session_id)
    {:ok, state}
  end

  defthen ~r/^a second attempt to retrieve the challenge should return "not_found"$/,
          _vars,
          state do
    assert {:error, :not_found} == AuthChallengeStore.pop_challenge(state.session_id)
    {:ok, state}
  end

  defthen ~r/^the system should return an "expired" error$/, _vars, state do
    assert {:error, :expired} == state.pop_result
    {:ok, state}
  end
end
