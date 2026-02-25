defmodule Nexus.Treasury.Projections.TreasuryPolicy do
  @moduledoc """
  Read-model projection for Treasury Policies.
  """
  use Nexus.Schema

  schema "treasury_policies" do
    field :org_id, :binary_id
    field :transfer_threshold, :decimal

    timestamps()
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:id, :org_id, :transfer_threshold])
    |> validate_required([:org_id, :transfer_threshold])
  end
end
