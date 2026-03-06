defmodule Nexus.Reporting.Projectors.AuditProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.AuditProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Events.TenantSuspended
  alias Nexus.Organization.Events.TenantModuleToggled
  alias Nexus.Reporting.Projections.AuditLog
  alias Nexus.Schema

  project(%TenantProvisioned{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_provisioned",
      actor_email: event.provisioned_by,
      org_id: event.org_id,
      tenant_name: event.name,
      details: %{admin_email: event.initial_admin_email},
      recorded_at: Nexus.Schema.parse_datetime(event.provisioned_at)
    })
  end)

  project(%TenantSuspended{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_suspended",
      actor_email: event.suspended_by,
      org_id: event.org_id,
      details: %{reason: event.reason},
      recorded_at: Nexus.Schema.parse_datetime(event.suspended_at)
    })
  end)

  project(%TenantModuleToggled{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_module_toggled",
      actor_email: event.toggled_by,
      org_id: event.org_id,
      details: %{module_name: event.module_name, enabled: event.enabled},
      recorded_at: Nexus.Schema.parse_datetime(event.toggled_at)
    })
  end)
end
