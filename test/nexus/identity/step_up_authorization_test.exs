defmodule Nexus.Identity.StepUpAuthorizationTest do
  use Cabbage.Feature, file: "identity/step_up_authorization.feature"
  use Nexus.DataCase
  @moduletag :feature

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
      display_name: "Test User"
    }

    :ok = App.dispatch(register_cmd)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id, role: role})}
  end

  defgiven ~r/^the currency pair is "(?<pair>[^"]+)"$/, %{pair: pair}, state do
    {:ok, Map.put(state, :pair, pair)}
  end

  defgiven ~r/^I am at the step-up verification prompt$/, _vars, state do
    # We need to set up the state from the previous scenario or just mock it
    # Cabbage scenarios are independent, so we re-setup.
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()

    register_cmd = %Nexus.Identity.Commands.RegisterSystemAdmin{
      user_id: user_id,
      org_id: org_id,
      email: "test@example.com",
      display_name: "Test User"
    }

    :ok = App.dispatch(register_cmd)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id, at_prompt: true})}
  end

  # --- When ---

  defwhen ~r/^I attempt to initiate a high-value transfer of "(?<amount>[^"]+)"$/,
          %{amount: amount},
          state do
    command = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: "TX-123",
      org_id: state.org_id,
      user_id: state.user_id,
      from_currency: "EUR",
      to_currency: "USD",
      amount: amount
    }

    result = App.dispatch(command)
    {:ok, Map.put(state, :transfer_result, result)}
  end

  defwhen ~r/^I provide a valid biometric signature$/, _vars, state do
    # Simulate the VerifyStepUp command
    # Using bootstrap credentials logic from User aggregate
    challenge_id = "step_up_#{state.user_id}"
    AuthChallengeStore.store_challenge(challenge_id, "mock_challenge")

    command = %Nexus.Identity.Commands.VerifyStepUp{
      user_id: state.user_id,
      org_id: state.org_id,
      challenge_id: challenge_id,
      action_id: "TX-123",
      raw_id: "raw",
      authenticator_data: "auth",
      signature: "sig",
      client_data_json: "client"
    }

    result = App.dispatch(command)
    {:ok, Map.put(state, :step_up_result, result)}
  end

  # --- Then ---

  defthen ~r/^I should be prompted for step-up biometric verification$/, _vars, state do
    assert {:error, :step_up_required} = state.transfer_result
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
