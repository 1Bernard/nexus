defmodule Nexus.Treasury.TransferHardeningTest do
  @moduledoc """
  Elite BDD tests for Treasury Transfer Hardening.
  """
  use Cabbage.Feature, file: "treasury/transfer_hardening.feature"
  use Nexus.DataCase

  import Commanded.Assertions.EventAssertions
  alias Nexus.App
  alias Nexus.Treasury
  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}
  alias Nexus.Identity.Events.{UserRegistered, StepUpVerified}
  alias Nexus.Identity.Commands.{RegisterUser, VerifyStepUp}
  alias Nexus.Treasury.ProcessManagers.TransferManager

  @moduletag :no_sandbox

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all("projection_versions")
      # Clear event store for the specific user and transfer streams to ensure isolation
      # In a real environment, we'd truncate the whole events table if we want a clean slate,
      # but since this test generates unique IDs, we focus on projection idempotency.
      Repo.query!("TRUNCATE event_store.events CASCADE")
    end)

    {:ok, %{}}
  end

  defgiven "an authorized user exists for an organization", _args, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

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

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(reg_cmd)
    end)

    assert_receive_event(App, UserRegistered, fn event ->
      event.user_id == user_id
    end)

    {:ok, %{org_id: org_id, user_id: user_id, pm_stream: "TransferHardeningTest.PM-#{user_id}"}}
  end

  defwhen ~r/^the user requests a transfer for "(?<amount>[^"]+)" (?<currency>[^"]+) (?<type>below|above) the "(?<threshold>[^"]+)" threshold$/,
          %{amount: amount, currency: currency, threshold: threshold},
          %{org_id: org_id, user_id: user_id} = state do
    transfer_id = Nexus.Schema.generate_uuidv7()

    attrs = %{
      transfer_id: transfer_id,
      org_id: org_id,
      user_id: user_id,
      from_currency: currency,
      to_currency: "USD",
      amount: Nexus.Schema.parse_decimal_safe(amount),
      threshold: Nexus.Schema.parse_decimal_safe(threshold)
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      assert :ok = Treasury.request_transfer(attrs)
    end)

    # Manually sync PM for TransferInitiated
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    Enum.each(events, &sync_transfer_pm(&1.data, state))

    {:ok, %{transfer_id: transfer_id}}
  end

  defwhen "the user verifies their step-up identity", _args, %{org_id: org_id, user_id: user_id, transfer_id: transfer_id} = state do
    verify_cmd = %VerifyStepUp{
      user_id: user_id,
      org_id: org_id,
      challenge_id: "test_challenge",
      action_id: transfer_id,
      verified_at: DateTime.utc_now()
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      assert :ok = App.dispatch(verify_cmd)
    end)

    # Manually sync PM for StepUpVerified
    {:ok, events} = Nexus.EventStore.read_stream_forward(user_id)
    sync_transfer_pm(List.last(events).data, state)

    # Now sync PM for resulting TransferAuthorized and TransferExecuted
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    Enum.each(events, &sync_transfer_pm(&1.data, state))

    :ok
  end

  defthen ~r/^the transfer should be "(?<status>[^"]+)"$/, %{status: status}, %{transfer_id: transfer_id} do
    assert_receive_event(App, TransferInitiated, fn event ->
      event.transfer_id == transfer_id && event.status == status
    end)

    :ok
  end

  defthen "the transfer should eventually be \"executed\"", _args, %{transfer_id: transfer_id} do
    assert_receive_event(App, TransferExecuted, fn event ->
      event.transfer_id == transfer_id
    end)

    :ok
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
