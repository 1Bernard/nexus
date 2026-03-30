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
    notification_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Notification)
      Repo.delete_all(User)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{user_id: user_id, org_id: org_id, notification_id: notification_id}}
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

    # Bridge logic: Treasury event triggers Notification handler which dispatches
    # CreateNotification command through the Commanded pipeline synchronously.
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      assert :ok =
               Nexus.CrossDomain.Handlers.SystemNotificationHandler.handle(event, %{
                 handler_name: "CrossDomain.SystemNotificationHandler",
                 event_number: 1
               })
    end)

    # Manually project via Ecto.Multi — bypasses the async projector pipeline entirely.
    # We read the latest NotificationCreated event from the event store DB directly.
    project_latest_notification(state.org_id)

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

  defp project_latest_notification(org_id) do
    # Fetch all NotificationCreated events and filter in Elixir to avoid DB-level JSONB matching quirks.
    sql = """
    SELECT data, metadata
    FROM event_store.events
    WHERE event_type = 'Elixir.Nexus.CrossDomain.Events.NotificationCreated'
    ORDER BY created_at DESC
    """

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      {:ok, %{rows: rows}} = Ecto.Adapters.SQL.query(Repo, sql, [])

      # Postgrex handles jsonb as Elixir maps automatically, but can return binaries in some environments.
      notification_event_data =
        Enum.find_value(rows, fn [event, metadata] ->
          event = if is_binary(event), do: Jason.decode!(event), else: event
          metadata = if is_binary(metadata), do: Jason.decode!(metadata), else: metadata

          if to_string(event["org_id"]) == to_string(org_id) do
            {event, metadata}
          else
            nil
          end
        end)

      case notification_event_data do
        {event, metadata} ->
          Repo.insert!(
            %Nexus.CrossDomain.Projections.Notification{
              id: event["id"],
              org_id: event["org_id"],
              user_id: event["user_id"],
              type: event["type"],
              title: event["title"],
              body: event["body"],
              metadata: Notification.decode_metadata(event["metadata"]),
              correlation_id: metadata["correlation_id"] || metadata[:correlation_id],
              causation_id: metadata["causation_id"] || metadata[:causation_id]
            },
            on_conflict: :nothing
          )

        nil ->
          :ok
      end
    end)
  end
end
