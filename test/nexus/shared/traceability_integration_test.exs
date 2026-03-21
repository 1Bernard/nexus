defmodule Nexus.Shared.TraceabilityIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Router
  alias Nexus.Reporting.Projections.AuditLog
  alias Nexus.CrossDomain.Projections.Notification
  alias Nexus.Repo

  @org_id "019d10fc-853f-73df-bb5d-5fc4ed37a1a8"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Nexus.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, {:shared, self()})

    org_id = Nexus.Schema.generate_uuidv7()
    # Start the projectors needed for this test
    start_supervised!(Nexus.Reporting.Projectors.AuditProjector)
    start_supervised!(Nexus.CrossDomain.Projectors.NotificationProjector)
    Repo.delete_all(AuditLog)
    Repo.delete_all(Notification)

    # Provision tenant
    provision_command = %Nexus.Organization.Commands.ProvisionTenant{
      org_id: org_id,
      name: "Traceability Test Org",
      initial_admin_email: "admin@trace-test.ai",
      provisioned_by: "system",
      provisioned_at: Nexus.Schema.utc_now()
    }
    assert :ok = Nexus.App.dispatch(provision_command)

    {:ok, org_id: org_id}
  end

  @tag :no_sandbox
  test "propagation of correlation_id from command to audit log and notification", %{org_id: org_id} do
    correlation_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    # Need to start SystemNotificationHandler too!
    start_supervised!(Nexus.CrossDomain.Handlers.SystemNotificationHandler)

    # Dispatch command with explicit correlation_id in metadata
    metadata = %{"correlation_id" => correlation_id}

    command = %Nexus.Identity.Commands.RegisterUser{
      org_id: org_id,
      user_id: user_id,
      email: "trace-#{user_id}@nexus.ai",
      display_name: "Trace Tester",
      role: "viewer",
      registered_at: Nexus.Schema.utc_now(),
      cose_key: "test_key",
      credential_id: "test_id"
    }

    assert :ok = Nexus.App.dispatch(command, metadata: metadata)

    # Wait for projections
    Process.sleep(3000)

    # 1. Verify Audit Log entry
    audit_log = Repo.get_by(AuditLog, correlation_id: correlation_id)
    assert audit_log != nil, "Audit log not found for correlation_id: #{correlation_id}"
    assert audit_log.correlation_id == correlation_id

    # 2. Verify Notification entry (triggered by UserRegistered via SystemNotificationHandler)
    notification = Repo.get_by(Notification, org_id: org_id, correlation_id: correlation_id)
    assert notification != nil, "Notification not found for correlation_id: #{correlation_id}"
    assert notification.correlation_id == correlation_id
    assert notification.type == "user_registered"
  end
end
