defmodule Nexus.Treasury.Commands.SetTransferThreshold do
  @moduledoc """
  Command to update the biometric step-up threshold for an organization.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  @primary_key {:policy_id, :binary_id, autogenerate: false}
  embedded_schema do
    field :org_id, :binary_id
    field :threshold, :decimal
  end

  def changeset(cmd, attrs) do
    cmd
    |> cast(attrs, [:policy_id, :org_id, :threshold])
    |> validate_required([:policy_id, :org_id, :threshold])
  end
end
