defmodule Nexus.Treasury.TransferHardeningTest do
  use Nexus.DataCase, async: false
  @moduletag :no_sandbox
  import Commanded.Assertions.EventAssertions

  alias Nexus.App
  alias Nexus.Treasury
  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}
  alias Nexus.Identity.Events.{UserRegistered, StepUpVerified}
  alias Nexus.Identity.Commands.{RegisterUser, VerifyStepUp}
  alias Nexus.Treasury.ProcessManagers.TransferManager

  setup do
    org_id = Uniq.UUID.uuid7()
    user_id = Uniq.UUID.uuid7()

    # Register the user
    reg_cmd = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: "test_#{user_id}@nexus.ai",
      display_name: "Test User",
      role: "admin",
      credential_id: "test_cred_#{user_id}",
      cose_key: "test_key_#{user_id}",
      registered_at: DateTime.utc_now()
    }

    :ok = App.dispatch(reg_cmd)

    assert_receive_event(App, UserRegistered, fn event ->
      event.user_id == user_id
    end)

    {:ok, org_id: org_id, user_id: user_id, pm_stream: "TransferHardeningTest.PM-#{user_id}"}
  end

  test "low-value transfer executes immediately", %{org_id: org_id, user_id: user_id} = state do
    transfer_id = Uniq.UUID.uuid7()

    attrs = %{
      transfer_id: transfer_id,
      org_id: org_id,
      user_id: user_id,
      from_currency: "EUR",
      to_currency: "USD",
      amount: "100",
      threshold: "1000000"
    }

    assert :ok = Treasury.request_transfer(attrs)

    # Manually sync PM for TransferInitiated
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    Enum.each(events, &sync_transfer_pm(&1.data, state))

    assert_receive_event(App, TransferInitiated, fn event ->
      event.transfer_id == transfer_id && event.status == "authorized"
    end)

    assert_receive_event(App, TransferExecuted, fn event ->
      event.transfer_id == transfer_id
    end)
  end

  test "high-value transfer requires step-up and then executes",
       %{org_id: org_id, user_id: user_id} = state do
    transfer_id = Uniq.UUID.uuid7()

    attrs = %{
      transfer_id: transfer_id,
      org_id: org_id,
      user_id: user_id,
      from_currency: "EUR",
      to_currency: "USD",
      amount: "5000000",
      threshold: "1000000"
    }

    assert :ok = Treasury.request_transfer(attrs)

    # Manually sync PM for TransferInitiated
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    Enum.each(events, &sync_transfer_pm(&1.data, state))

    assert_receive_event(App, TransferInitiated, fn event ->
      event.transfer_id == transfer_id && event.status == "pending_authorization"
    end)

    # Now verify step-up
    verify_cmd = %VerifyStepUp{
      user_id: user_id,
      org_id: org_id,
      challenge_id: "test_challenge",
      action_id: transfer_id,
      verified_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(verify_cmd)

    # Manually sync PM for StepUpVerified
    {:ok, events} = Nexus.EventStore.read_stream_forward(user_id)
    # Only sync the latest event (StepUpVerified)
    sync_transfer_pm(List.last(events).data, state)

    # Now sync PM for resulting TransferAuthorized and TransferExecuted
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    Enum.each(events, &sync_transfer_pm(&1.data, state))

    assert_receive_event(App, TransferAuthorized, fn event ->
      event.transfer_id == transfer_id
    end)

    assert_receive_event(App, TransferExecuted, fn event ->
      event.transfer_id == transfer_id
    end)
  end

  # --- Manual PM Sync Helper ---
  defp sync_transfer_pm(event, state) do
    # Replay PM state
    pm_state =
      case Nexus.EventStore.read_stream_forward(state.pm_stream) do
        {:ok, events} ->
          Enum.reduce(events, %TransferManager{}, fn %{data: e}, acc ->
            TransferManager.apply(acc, e)
          end)

        _ ->
          %TransferManager{}
      end

    # Handle event (emit commands)
    case TransferManager.handle(pm_state, event) do
      [] ->
        :ok

      command when is_struct(command) ->
        assert :ok = App.dispatch(command)

      commands when is_list(commands) ->
        Enum.each(commands, fn c -> assert :ok = App.dispatch(c) end)
    end

    # Persist PM state change
    new_pm_state = TransferManager.apply(pm_state, event)

    event_data = %EventStore.EventData{
      event_type: to_string(event.__struct__),
      data: event,
      metadata: %{}
    }

    Nexus.EventStore.append_to_stream(state.pm_stream, :any_version, [event_data])
  end
end
