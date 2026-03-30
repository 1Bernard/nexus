defmodule Nexus.Treasury.Projections.NettingCycle do
  @moduledoc """
  Read model for a treasury netting cycle.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :currency,
             :status,
             :total_amount,
             :period_start,
             :period_end
           ]}
  schema "treasury_netting_cycles" do
    field :org_id, :binary_id
    field :currency, :string
    field :status, :string, default: "active"
    field :total_amount, :decimal, default: 0
    field :period_start, :utc_datetime_usec
    field :period_end, :utc_datetime_usec

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :org_id, :currency, :status, :total_amount, :period_start, :period_end])
    |> validate_required([:id, :org_id, :currency, :status])
  end
end
