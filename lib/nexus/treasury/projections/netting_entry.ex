defmodule Nexus.Treasury.Projections.NettingEntry do
  @moduledoc """
  Read model for an individual invoice entry within a netting cycle.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :netting_id,
             :invoice_id,
             :subsidiary,
             :amount,
             :currency
           ]}
  schema "treasury_netting_entries" do
    field :netting_id, :binary_id
    field :invoice_id, :binary_id
    field :subsidiary, :string
    field :amount, :decimal
    field :currency, :string

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :netting_id, :invoice_id, :subsidiary, :amount, :currency])
    |> validate_required([:id, :netting_id, :invoice_id, :amount, :currency])
  end
end
