defmodule Nexus.CrossDomain.NotificationsTest do
  use Nexus.DataCase
  import Commanded.Assertions.EventAssertions

  alias Nexus.App
  alias Nexus.CrossDomain.Events.NotificationCreated
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Repo

  setup do
    # Start notification components in isolation for this test
    # This prevents them from interfering with other tests while ensuring
    # the integration logic is verified.
    start_supervised!(Nexus.CrossDomain.Projectors.NotificationProjector)
    start_supervised!(Nexus.CrossDomain.Handlers.SystemNotificationHandler)
    :ok
  end

  test "receiving a notification via bridge" do
    org_id = Nexus.Schema.generate_uuidv7()
    # 1. Trigger the bridge event
    event = %Nexus.Treasury.Events.PolicyAlertTriggered{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      currency_pair: "EUR/USD",
      threshold: Decimal.new("50000"),
      exposure_amount: Decimal.new("55000"),
      triggered_at: DateTime.utc_now()
    }

    # Dispatch via the handler (simulated or direct)
    # Since SystemNotificationHandler is an event handler, it will react to the event store.
    # We'll just verify the resulting command was dispatched/processed.

    # Instead of full BDD (which requires browser), we'll do an integration test for the bridge.
    Nexus.CrossDomain.Handlers.SystemNotificationHandler.handle(event, %{})

    assert_receive_event(App, NotificationCreated, fn e ->
      e.org_id == org_id and e.type == "treasury_alert"
    end)

    # Verify projection with polling to account for catch-up
    assert_eventually_projected(org_id, "treasury_alert")
  end

  defp assert_eventually_projected(org_id, type, retries \\ 10)
  defp assert_eventually_projected(_org_id, _type, 0), do: flunk("Notification not projected in time")
  defp assert_eventually_projected(org_id, type, retries) do
    if Repo.get_by(Notification, org_id: org_id, type: type) do
      :ok
    else
      Process.sleep(200)
      assert_eventually_projected(org_id, type, retries - 1)
    end
  end
end
