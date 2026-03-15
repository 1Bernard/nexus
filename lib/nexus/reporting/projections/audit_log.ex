defmodule Nexus.Reporting.Projections.AuditLog do
  @moduledoc """
  Read-model schema for the reporting_audit_logs table.
  Records a tamper-evident trail of organisation-level events for compliance and audit purposes.
  """
  use Nexus.Schema

  schema "reporting_audit_logs" do
    field :event_type, :string
    field :actor_email, :string
    field :org_id, :binary_id
    field :tenant_name, :string
    field :details, :map
    field :correlation_id, :binary_id
    field :causation_id, :binary_id
    field :recorded_at, :utc_datetime_usec

    timestamps()
  end
end
