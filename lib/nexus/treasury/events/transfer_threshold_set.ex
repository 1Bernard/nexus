defmodule Nexus.Treasury.Events.TransferThresholdSet do
  @moduledoc """
  Event emitted when an organization's biometric threshold is updated.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  @primary_key {:policy_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :org_id, :binary_id
    field :threshold, :decimal
    field :set_at, :utc_datetime
  end

  def changeset(ev, attrs) do
    ev
    |> cast(attrs, [:policy_id, :org_id, :threshold, :set_at])
    |> validate_required([:policy_id, :org_id, :threshold, :set_at])
  end
end
