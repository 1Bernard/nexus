defmodule Nexus.Reporting.Projectors.AuditProjector do
  @moduledoc """
  Listens for organisation-lifecycle events and writes immutable audit records
  to the reporting_audit_logs table.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.AuditProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Events.TenantSuspended
  alias Nexus.Organization.Events.TenantModuleToggled

  alias Nexus.Treasury.Events.{
    TransferThresholdSet,
    TransferAuthorized,
    TransferExecuted,
    ReconciliationProposed,
    ReconciliationReversed,
    ReconciliationRejected
  }

  alias Nexus.Identity.Events.{UserRegistered, UserRoleChanged, BiometricVerified, StepUpVerified}
  alias Nexus.ERP.Events.{InvoiceMatched, StatementUploaded}
  alias Nexus.Reporting.Projections.{AuditLog, ControlDrift}
  alias Nexus.Schema

  project(%TenantProvisioned{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_provisioned",
      actor_email: event.provisioned_by,
      org_id: event.org_id,
      tenant_name: event.name,
      details: %{admin_email: event.initial_admin_email},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.provisioned_at)
    })
  end)

  project(%TenantSuspended{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_suspended",
      actor_email: event.suspended_by,
      org_id: event.org_id,
      details: %{reason: event.reason},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.suspended_at)
    })
  end)

  project(%TenantModuleToggled{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "tenant_module_toggled",
      actor_email: event.toggled_by,
      org_id: event.org_id,
      details: %{module_name: event.module_name, enabled: event.enabled},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.toggled_at)
    })
    |> upsert_drift(
      event.org_id,
      "module_#{event.module_name}",
      to_string(event.enabled),
      event.toggled_at
    )
  end)

  project(%TransferThresholdSet{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "financial_policy_updated",
      actor_email: "system@nexus.ai",
      org_id: event.org_id,
      details: %{threshold: event.threshold, policy_id: event.policy_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.set_at)
    })
    |> upsert_drift(
      event.org_id,
      "treasury_threshold",
      to_string(event.threshold),
      event.set_at
    )
  end)

  project(%UserRegistered{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "user_registered",
      actor_email: event.email,
      org_id: event.org_id,
      details: %{display_name: event.display_name, role: event.role},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.registered_at)
    })
  end)

  project(%UserRoleChanged{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "user_role_changed",
      actor_email: event.actor_id,
      org_id: event.org_id,
      details: %{user_id: event.user_id, role: event.role},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.changed_at)
    })
    |> upsert_drift(
      event.org_id,
      "user_role_#{event.user_id}",
      event.role,
      event.changed_at
    )
  end)

  project(%TransferAuthorized{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "transfer_authorized",
      actor_email: event.actor_email,
      org_id: event.org_id,
      details: %{transfer_id: event.transfer_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.authorized_at)
    })
  end)

  project(%TransferExecuted{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "transfer_executed",
      actor_email: "system@nexus.ai",
      org_id: event.org_id,
      details: %{
        transfer_id: event.transfer_id,
        amount: event.amount,
        from_currency: event.from_currency,
        to_currency: event.to_currency
      },
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.executed_at)
    })
  end)

  project(%InvoiceMatched{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "invoice_matched",
      actor_email: event.actor_email,
      org_id: event.org_id,
      details: %{
        invoice_id: event.invoice_id,
        matched_id: event.matched_id,
        matched_type: event.matched_type
      },
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.matched_at)
    })
  end)

  project(%StatementUploaded{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "statement_uploaded",
      actor_email: "system@nexus.ai",
      org_id: event.org_id,
      details: %{
        statement_id: event.statement_id,
        filename: event.filename,
        format: event.format
      },
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.uploaded_at)
    })
  end)

  project(%ReconciliationProposed{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "reconciliation_proposed",
      actor_email: event.actor_email,
      org_id: event.org_id,
      details: %{
        reconciliation_id: event.reconciliation_id,
        amount: event.amount,
        currency: event.currency
      },
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.timestamp)
    })
  end)

  project(%ReconciliationRejected{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "reconciliation_rejected",
      actor_email: event.rejector_email,
      org_id: event.org_id,
      details: %{reconciliation_id: event.reconciliation_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.timestamp)
    })
  end)

  project(%ReconciliationReversed{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "reconciliation_reversed",
      actor_email: event.actor_email,
      org_id: event.org_id,
      details: %{reconciliation_id: event.reconciliation_id, invoice_id: event.invoice_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.timestamp)
    })
  end)

  project(%BiometricVerified{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "security_biometric_verified",
      actor_email: "user_#{event.user_id}",
      org_id: event.org_id,
      details: %{handshake_id: event.handshake_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.verified_at)
    })
  end)

  project(%StepUpVerified{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :audit_log, %AuditLog{
      id: Schema.generate_uuidv7(),
      event_type: "security_step_up_verified",
      actor_email: "user_#{event.user_id}",
      org_id: event.org_id,
      details: %{action_id: event.action_id},
      correlation_id: Map.get(metadata, "correlation_id") || Map.get(metadata, :correlation_id),
      causation_id: Map.get(metadata, "causation_id") || Map.get(metadata, :causation_id),
      recorded_at: Nexus.Schema.parse_datetime(event.verified_at)
    })
  end)

  defp upsert_drift(multi, org_id, control_key, value, timestamp) do
    Ecto.Multi.run(multi, "drift_#{control_key}", fn repo, _ ->
      timestamp = Nexus.Schema.parse_datetime(timestamp)

      case repo.get_by(ControlDrift, org_id: org_id, control_key: control_key) do
        nil ->
          repo.insert(%ControlDrift{
            id: Schema.generate_uuidv7(),
            org_id: org_id,
            control_key: control_key,
            original_value: value,
            current_value: value,
            drift_score: Decimal.new(0),
            last_changed_at: timestamp
          })

        drift ->
          new_score = Decimal.add(drift.drift_score, 1)

          drift
          |> ControlDrift.changeset(%{
            current_value: value,
            drift_score: new_score,
            last_changed_at: timestamp
          })
          |> repo.update()
      end
    end)
  end
end
