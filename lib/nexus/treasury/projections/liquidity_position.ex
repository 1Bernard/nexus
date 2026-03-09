defmodule Nexus.Treasury.Projections.LiquidityPosition do
  @moduledoc """
  Read model for the current liquid balance per organization and currency.
  """
  use Nexus.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "treasury_liquidity_positions" do
    field :org_id, :binary_id
    field :currency, :string
    field :amount, :decimal, default: 0

    timestamps()
  end

  def changeset(position, attrs) do
    position
    |> cast(attrs, [:id, :org_id, :currency, :amount])
    |> validate_required([:id, :org_id, :currency, :amount])
  end
end
