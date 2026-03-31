defmodule Nexus.Treasury.Commands.CompleteNettingCycleSettlement do
  @moduledoc """
  Internal command to finalize the netting cycle settlement.
  """
  use Nexus.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :netting_id, :binary_id
    field :org_id, :binary_id
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:netting_id, :org_id])
    |> validate_required([:netting_id, :org_id])
  end
end
