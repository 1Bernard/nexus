defmodule Nexus.Treasury.Commands.ScanInvoicesForNetting do
  @moduledoc """
  Command to trigger an automated scan of ERP invoices for a netting cycle.
  """
  use Nexus.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :netting_id, :binary_id
    field :org_id, :binary_id
    field :user_id, :binary_id
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:netting_id, :org_id, :user_id])
    |> validate_required([:netting_id, :org_id, :user_id])
  end
end
