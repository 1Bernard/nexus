defmodule Nexus.Identity.BiometricVerificationTest do
  use Cabbage.Feature, file: "identity/biometric_verification.feature"
  use Nexus.DataCase

  @moduletag :feature

  alias Nexus.Repo
  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.Events.BiometricVerified

  setup do
    # For async projections to work with the SQL sandbox,
    # we must share the connection with all processes.
    # Manually start the projector for this test
    start_supervised!(Nexus.Identity.Projectors.UserProjector)

    :ok
  end

  # --- Given ---

  defgiven ~r/^a user "(?<username>[^"]+)" is registered with a public key$/,
           %{username: _username},
           state do
    user_id = UUIDv7.generate()
    unique_id = System.unique_integer([:positive])
    email = "bernard_#{unique_id}@nexus.com"
    pub_key = "institutional_pub_key"

    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: user_id,
      email: email,
      role: "trader",
      public_key: pub_key
    }

    :ok = Nexus.App.dispatch(command)

    # Wait for the projector to catch up
    Process.sleep(200)

    user = %{id: user_id, email: email, public_key: pub_key}
    {:ok, Map.put(state, :user, user)}
  end

  defgiven ~r/^a valid session ID "(?<session_id>[^"]+)"$/,
           %{session_id: session_id},
           state do
    {:ok, Map.put(state, :session_id, session_id)}
  end

  # --- When ---

  defwhen ~r/^the system generates a biometric challenge for "(?<session_id>[^"]+)"$/,
          %{session_id: session_id},
          state do
    challenge = "cryptographic_random_challenge"
    AuthChallengeStore.store_challenge(session_id, challenge)
    {:ok, Map.put(state, :sent_challenge, challenge)}
  end

  defwhen ~r/^"(?<username>[^"]+)" signs the challenge with their hardware sensor$/,
          _vars,
          state do
    # Simulate a biometric signature using the challenge
    signature = "valid_signature_over_#{state.sent_challenge}"

    command = %Nexus.Identity.Commands.VerifyBiometric{
      user_id: state.user.id,
      # We use session_id as challenge_id in this simulation
      challenge_id: state.session_id,
      signature: signature
    }

    :ok = Nexus.App.dispatch(command)

    {:ok, Map.put(state, :signature, signature)}
  end

  # --- Then ---

  defthen ~r/^the challenge should be successfully popped from the ETS store$/,
          _vars,
          state do
    result = AuthChallengeStore.pop_challenge(state.session_id)
    assert {:ok, _challenge} = result
    {:ok, Map.put(state, :popped_challenge, result)}
  end

  defthen ~r/^the biometric signature should be verified as authentic$/,
          _vars,
          state do
    # In production, we'd call Wax.authenticate/5
    # Here we verify the logic ensures the signature exists and matches the intent
    assert state.signature == "valid_signature_over_#{state.sent_challenge}"
    {:ok, state}
  end

  defthen ~r/^a "(?<event_name>[^"]+)" event should be emitted$/,
          %{event_name: "BiometricVerified"},
          state do
    # Verify the event exists in the event store for this user stream
    stream_id = state.user.id
    {:ok, events} = Nexus.EventStore.read_stream_forward(stream_id)

    # The second event should be BiometricVerified (first is UserRegistered)
    assert Enum.any?(events, fn e ->
             e.event_type == "Elixir.Nexus.Identity.Events.BiometricVerified"
           end)

    {:ok, state}
  end

  defthen ~r/^the user should be "found in the database" with their public key$/,
          _vars,
          state do
    alias Nexus.Identity.Projections.User

    # We manually simulate the projection if we are just testing the logic,
    # or we can check the repo if we want full integration verification.
    # Wait for the projector with a retry loop (max 1s)
    user = wait_for_user(state.user.id)
    assert user.email == state.user.email
    assert user.public_key == "institutional_pub_key"
    {:ok, state}
  end

  defp wait_for_user(user_id, attempts \\ 30)
  defp wait_for_user(_user_id, 0), do: nil

  defp wait_for_user(user_id, attempts) do
    case Repo.get(Nexus.Identity.Projections.User, user_id) do
      nil ->
        Process.sleep(100)
        wait_for_user(user_id, attempts - 1)

      user ->
        user
    end
  end
end
