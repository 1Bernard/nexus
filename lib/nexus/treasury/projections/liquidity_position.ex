defmodule Nexus.Treasury.Projections.LiquidityPosition do
  @moduledoc """
  Read model for the current liquid balance per organization and currency.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:id, :org_id, :currency, :amount]}
  schema "treasury_liquidity_positions" do
    field :org_id, :binary_id
    field :currency, :string
    field :amount, :decimal, default: 0

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(position, attrs) do
    position
    |> cast(attrs, [:id, :org_id, :currency, :amount])
    |> validate_required([:id, :org_id, :currency, :amount])
  end
end
