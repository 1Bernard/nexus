defmodule Nexus.CrossDomain.NotificationsTest do
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  alias Nexus.App
  alias Nexus.CrossDomain.Events.NotificationCreated
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Repo

  setup do
    :ok
  end

  test "receiving a notification via bridge" do
    org_id = Nexus.Schema.generate_uuidv7()
    _user_id = Nexus.Schema.generate_uuidv7()

    # 1. Trigger the bridge event
    event = %Nexus.Treasury.Events.PolicyAlertTriggered{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      currency_pair: "EUR/USD",
      threshold: Decimal.new("50000"),
      exposure_amount: Decimal.new("55000"),
      triggered_at: DateTime.utc_now()
    }

    # 2. Capture the command dispatched by the handler
    # We use a handler that dispatches a command.
    Nexus.CrossDomain.Handlers.SystemNotificationHandler.handle(event, %{})

    # 3. Read the event from the EventStore to get the notification data
    # (Since we dispatched a command, an event should have been emitted)
    recorded_event =
      wait_for_event(App, NotificationCreated, fn e ->
        e.org_id == org_id and e.type == "treasury_alert"
      end)

    # 4. Manually project the event using unboxed_run (Standard 7 compliance)
    project_event(recorded_event.data, recorded_event.event_number)

    # 5. Verify projection
    snapshot = get_notification(recorded_event.data.id)
    assert snapshot != nil
    assert snapshot.type == "treasury_alert"
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "CrossDomain.NotificationProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.CrossDomain.Projectors.NotificationProjector.handle(event, metadata)
    end)
  end

  defp get_notification(id) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.get(Notification, id)
    end)
  end
end
