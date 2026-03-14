defmodule Nexus.Treasury.Projections.PolicyAuditLog do
  @moduledoc """
  Read-model projection for Treasury Policy Audit Logs.
  """
  use Nexus.Schema

  schema "treasury_policy_audit_logs" do
    field :org_id, :binary_id
    field :actor_email, :string
    field :mode, :string
    field :threshold, :decimal
    field :changed_at, :utc_datetime_usec
    field :org_name, :string, virtual: true

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:org_id, :actor_email, :mode, :threshold, :changed_at])
    |> validate_required([:org_id, :actor_email, :mode, :threshold, :changed_at])
  end
end
