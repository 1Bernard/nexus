defmodule Nexus.Treasury.Projections.TreasuryPolicy do
  @moduledoc """
  Read-model projection for Treasury Policies.
  """
  use Nexus.Schema

  schema "treasury_policies" do
    field :org_id, :binary_id
    field :transfer_threshold, :decimal
    field :mode, :string, default: "standard"

    timestamps()
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:id, :org_id, :transfer_threshold, :mode])
    |> validate_required([:org_id, :transfer_threshold, :mode])
    |> validate_inclusion(:mode, ~w[standard strict relaxed])
  end
end
