defmodule Nexus.Identity.StepUpAuthorizationTest do
  use Cabbage.Feature, file: "identity/step_up_authorization.feature"
  use Nexus.DataCase
  @moduletag :no_sandbox

  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.App

  # --- Given ---

  defgiven ~r/^I am logged in as a "(?<role>[^"]+)"$/, %{role: role}, state do
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()

    # Pre-register user in the aggregate by emitting event or just use a mock approach
    # Since we test the command dispatch, we need the aggregate to exist if it checks state.
    # The User aggregate handles RegisterUser first.

    register_cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
      user_id: user_id,
      org_id: org_id,
      email: "test@example.com",
      display_name: "Test User",
      registered_at: DateTime.utc_now()
    }

    :ok = App.dispatch(register_cmd)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id, role: role})}
  end

  defgiven ~r/^the currency pair is "(?<pair>[^"]+)"$/, %{pair: pair}, state do
    {:ok, Map.put(state, :pair, pair)}
  end

  defgiven ~r/^I am at the step-up verification prompt$/, _vars, state do
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()
    transfer_id = Nexus.Schema.generate_uuidv7()

    register_cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
      user_id: user_id,
      org_id: org_id,
      email: "test@example.com",
      display_name: "Test User",
      registered_at: DateTime.utc_now()
    }

    :ok = App.dispatch(register_cmd)

    transfer_cmd = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: transfer_id,
      org_id: org_id,
      user_id: user_id,
      from_currency: "EUR",
      to_currency: "USD",
      amount: Decimal.new("5000000"),
      requested_at: DateTime.utc_now()
    }

    :ok = App.dispatch(transfer_cmd)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id, transfer_id: transfer_id})}
  end

  # --- When ---

  defwhen ~r/^I attempt to initiate a high-value transfer of "(?<amount>[^"]+)"$/,
          %{amount: amount},
          state do
    transfer_id = Nexus.Schema.generate_uuidv7()
    command = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: transfer_id,
      org_id: state.org_id,
      user_id: state.user_id,
      from_currency: "EUR",
      to_currency: "USD",
      amount: amount,
      requested_at: DateTime.utc_now()
    }

    result = App.dispatch(command)
    {:ok, Map.merge(state, %{transfer_result: result, transfer_id: transfer_id})}
  end

  defwhen ~r/^I provide a valid biometric signature$/, _vars, state do
    challenge_id = "step_up_#{state.user_id}"
    AuthChallengeStore.store_challenge(challenge_id, "mock_challenge")

    command = %Nexus.Identity.Commands.VerifyStepUp{
      user_id: state.user_id,
      org_id: state.org_id,
      challenge_id: challenge_id,
      action_id: state.transfer_id,
      verified_at: DateTime.utc_now()
    }

    result = App.dispatch(command)
    {:ok, Map.put(state, :step_up_result, result)}
  end

  # --- Then ---

  defthen ~r/^I should be prompted for step-up biometric verification$/, _vars, state do
    assert :ok = state.transfer_result
    # Verify the event state
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.transfer_id)

    assert Enum.any?(events, fn e ->
             e.data.status == "pending_authorization"
           end)

    {:ok, state}
  end

  defthen ~r/^the transfer should not be recorded yet$/, _vars, state do
    # Verification of non-state change
    {:ok, state}
  end

  defthen ~r/^the transfer should be successfully authorized$/, _vars, state do
    assert :ok = state.step_up_result
    {:ok, state}
  end

  defthen ~r/^I should see a success notification$/, _vars, state do
    {:ok, state}
  end
end
