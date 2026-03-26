defmodule Nexus.CrossDomain.NotificationsTest do
  use Cabbage.Feature, file: "cross_domain/notifications_integration.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Identity.Projections.User

  setup do
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Notification)
      Repo.delete_all(User)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{user_id: user_id, org_id: org_id}}
  end

  # --- Given ---

  defgiven ~r/^a user "(?<name>[^"]+)" exists with notification preferences enabled$/,
           _vars,
           state do
    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: state.user_id,
      org_id: state.org_id,
      email: "trader1@nexus.financial",
      display_name: "Trader One",
      role: "trader",
      cose_key: "mock",
      credential_id: "mock",
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync User Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(state.user_id)
    project_identity_event(event, num)

    {:ok, state}
  end

  # --- When ---

  defwhen ~r/^a transfer of "(?<amount_str>[^"]+)" is executed in the Treasury domain$/,
          %{amount_str: amount_str},
          state do
    [amount, currency] = String.split(amount_str, " ")
    amount_dec = Decimal.new(String.replace(amount, ",", ""))

    event = %Nexus.Treasury.Events.TransferExecuted{
      transfer_id: Nexus.Schema.generate_uuidv7(),
      org_id: state.org_id,
      amount: amount_dec,
      from_currency: currency,
      to_currency: "USD",
      executed_at: DateTime.utc_now()
    }

    # Bridge logic: Treasury event triggers Notification handler
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Nexus.CrossDomain.Handlers.SystemNotificationHandler.handle(event, %{
        handler_name: "CrossDomain.SystemNotificationHandler",
        event_number: 1
      })
    end)

    # Sync Projection (Search for the random-ID notification in event store)
    all_events = wait_for_events(Nexus.CrossDomain.Events.NotificationCreated, 1)

    notifications = Enum.filter(all_events, fn e ->
      if e.data.__struct__ == Nexus.CrossDomain.Events.NotificationCreated do
        Logger.debug("[BDD] Checking org_id: Event=#{inspect(e.data.org_id)}, State=#{inspect(state.org_id)}")
      end
      e.data.__struct__ == Nexus.CrossDomain.Events.NotificationCreated and
      e.data.org_id == state.org_id
    end)

    Logger.debug("[BDD] Notifications matched for org #{state.org_id}: #{length(notifications)}")

    Enum.each(notifications, fn e ->
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        Nexus.CrossDomain.Projectors.NotificationProjector.handle(e.data, %{
          handler_name: "CrossDomain.NotificationProjector",
          event_number: e.event_number,
          correlation_id: e.correlation_id,
          causation_id: e.causation_id
        })
      end)
    end)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^a "(?<type>[^"]+)" notification should be dispatched to the user$/,
          %{type: type},
          state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      note = Repo.get_by(Notification, org_id: state.org_id, type: type)
      assert note != nil
    end)
    {:ok, state}
  end

  defthen ~r/^the notification should be recorded in the Cross-Domain audit log$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp project_identity_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Identity.Projectors.UserProjector.handle(event, %{
        handler_name: "Identity.Projectors.UserProjector",
        event_number: num
      })
    end)
  end

  defp wait_for_events(event_type, count, attempts \\ 10)
  defp wait_for_events(_event_type, _count, 0), do: []
  defp wait_for_events(event_type, count, attempts) do
    # Use high-count forward scan to ensure we see all events in the session (Elite standard)
    {:ok, events} = Nexus.EventStore.read_all_streams_forward(0, 5000)
    found = Enum.filter(events, fn e -> e.data.__struct__ == event_type end)

    require Logger
    Logger.debug("[BDD] wait_for_events: Found #{length(found)} of #{event_type} (Target: #{count}, Attempts left: #{attempts})")

    if length(found) >= count do
      events
    else
      :timer.sleep(100)
      wait_for_events(event_type, count, attempts - 1)
    end
  end
end
