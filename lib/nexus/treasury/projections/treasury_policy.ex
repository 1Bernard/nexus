defmodule Nexus.Treasury.Projections.TreasuryPolicy do
  @moduledoc """
  Read-model projection for Treasury Policies.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :transfer_threshold, :mode, :mode_thresholds, :reporting_currency, :target_allocations, :rebalance_threshold]}
  schema "treasury_policies" do
    field :org_id, :binary_id
    field :transfer_threshold, :decimal
    field :mode, :string, default: "standard"
    field :reporting_currency, :string, default: "USD"

    field :mode_thresholds, :map,
      default: %{"standard" => "1000000", "strict" => "50000", "relaxed" => "10000000"}

    field :target_allocations, :map, default: %{}
    field :rebalance_threshold, :decimal, default: 0.05

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :id,
      :org_id,
      :transfer_threshold,
      :mode,
      :mode_thresholds,
      :reporting_currency,
      :target_allocations,
      :rebalance_threshold
    ])
    |> validate_required([:org_id, :transfer_threshold, :mode, :reporting_currency])
    |> validate_inclusion(:mode, ~w[standard strict relaxed])
  end
end
