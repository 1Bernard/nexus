defmodule Nexus.Treasury.Commands.InitializeNettingCycle do
  @moduledoc """
  Command to start a new intercompany netting cycle.
  """
  use Nexus.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :netting_id, :binary_id
    field :org_id, :binary_id
    field :currency, :string
    field :period_start, :utc_datetime_usec
    field :period_end, :utc_datetime_usec
    field :user_id, :binary_id
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:netting_id, :org_id, :currency, :period_start, :period_end, :user_id])
    |> validate_required([:netting_id, :org_id, :currency, :period_start, :period_end, :user_id])
  end
end
