defmodule Nexus.Reporting.Projections.AuditLog do
  @moduledoc """
  Read-model schema for the reporting_audit_logs table.
  Records a tamper-evident trail of organisation-level events for compliance and audit purposes.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :event_type,
             :actor_email,
             :org_id,
             :tenant_name,
             :details,
             :correlation_id,
             :causation_id,
             :recorded_at
           ]}
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

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :id,
      :event_type,
      :actor_email,
      :org_id,
      :tenant_name,
      :details,
      :correlation_id,
      :causation_id,
      :recorded_at
    ])
    |> validate_required([:id, :event_type, :org_id, :recorded_at])
  end
end
