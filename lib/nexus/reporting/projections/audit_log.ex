defmodule Nexus.Reporting.Projections.AuditLog do
  use Nexus.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "reporting_audit_logs" do
    field :event_type, :string
    field :actor_email, :string
    field :org_id, :binary_id
    field :tenant_name, :string
    field :details, :map
    field :recorded_at, :utc_datetime_usec

    timestamps()
  end
end
