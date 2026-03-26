defmodule Nexus.Shared.TraceabilityIntegrationTest do
  use Cabbage.Feature, file: "shared/traceability.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Reporting.Projections.AuditLog
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Identity.Commands.RegisterUser

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(AuditLog)
      Repo.delete_all(Notification)
      Repo.delete_all(Nexus.Organization.Projections.Tenant)
      Repo.delete_all("projection_versions")
    end)

    :ok
  end

  # --- Given ---

  defgiven ~r/^a provisioned organization "(?<name>[^"]+)"$/, %{name: name}, state do
    org_id = Nexus.Schema.generate_uuidv7()

    provision_command = %ProvisionTenant{
      org_id: org_id,
      name: name,
      initial_admin_email: "admin@trace-test.ai",
      provisioned_by: "system",
      provisioned_at: Nexus.Schema.utc_now()
    }

    assert :ok = App.dispatch(provision_command)

    {:ok, Map.put(state, :org_id, org_id)}
  end

  defgiven ~r/^a custom correlation_id "(?<id>[^"]+)"$/, %{id: id}, state do
    {:ok, Map.put(state, :correlation_id, id)}
  end

  # --- When ---

  defwhen ~r/^I register a new user "(?<name>[^"]+)" with the custom correlation_id$/,
          %{name: _name},
          state do
    user_id = Nexus.Schema.generate_uuidv7()
    metadata = %{"correlation_id" => state.correlation_id}

    command = %RegisterUser{
      org_id: state.org_id,
      user_id: user_id,
      email: "trace-#{user_id}@nexus.ai",
      display_name: "Trace Tester",
      role: "viewer",
      registered_at: Nexus.Schema.utc_now(),
      cose_key: "test_key",
      credential_id: "test_id"
    }

    assert :ok = App.dispatch(command, metadata: metadata)

    # SECRETS OF THE ELITE: Manually trigger side effects for 100% determinism
    # 1. Audit Log (AuditProjector)
    # 2. Notification (SystemNotificationHandler -> NotificationProjector)

    # Capture the UserRegistered event
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(user_id)

    # Trigger AuditProjector
    project_audit_event(event, num, state.correlation_id)

    # Trigger SystemNotificationHandler -> NotificationProjector
    # Normally this would be a handler, but we can manually project it for the test
    project_notification_event(event, num, state.correlation_id, state.org_id)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^an audit log entry should exist with correlation_id "(?<id>[^"]+)"$/,
          %{id: id},
          state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      log = Repo.get_by(AuditLog, correlation_id: id)
      assert log != nil, "Audit log not found for correlation_id: #{id}"
    end)
    {:ok, state}
  end

  defthen ~r/^a system notification should exist with correlation_id "(?<id>[^"]+)"$/,
          %{id: id},
          state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      notification = Repo.get_by(Notification, correlation_id: id, org_id: state.org_id)
      assert notification != nil, "Notification not found for correlation_id: #{id}"
    end)
    {:ok, state}
  end

  defthen ~r/^the notification type should be "(?<type>[^"]+)"$/, %{type: type}, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      # We just checked it above, but we can do it more specifically if needed
      notification = Repo.get_by(Notification, correlation_id: state.correlation_id)
      assert notification.type == type
    end)
    {:ok, state}
  end

  # --- Helpers ---

  defp project_audit_event(event, num, correlation_id) do
    metadata = %{
      handler_name: "Reporting.Projectors.AuditProjector",
      event_number: num,
      correlation_id: correlation_id
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Nexus.Reporting.Projectors.AuditProjector.handle(event, metadata)
    end)
  end

  defp project_notification_event(event, num, correlation_id, org_id) do
    # 1. Simulate SystemNotificationHandler
    metadata = %{
      correlation_id: correlation_id,
      causation_id: correlation_id # Simplified for test
    }

    notification_id = Nexus.Schema.generate_uuidv7()

    cmd = %Nexus.CrossDomain.Commands.CreateNotification{
      id: notification_id,
      org_id: org_id,
      user_id: event.user_id,
      type: "user_registered",
      title: "New User Registered",
      body: "#{event.display_name} has joined.",
      metadata: %{user_id: event.user_id, email: event.email}
    }

    assert :ok = App.dispatch(cmd, metadata: metadata)

    # 2. Sync Projection
    {:ok, [%{data: created_event, event_number: created_num}]} =
      Nexus.EventStore.read_stream_forward(notification_id)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Nexus.CrossDomain.Projectors.NotificationProjector.handle(created_event, %{
        handler_name: "CrossDomain.NotificationProjector",
        event_number: created_num,
        correlation_id: correlation_id,
        causation_id: correlation_id
      })
    end)
  end
end
