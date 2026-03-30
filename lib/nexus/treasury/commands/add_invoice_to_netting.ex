defmodule Nexus.Treasury.Commands.AddInvoiceToNetting do
  @moduledoc """
  Command to link an ERP invoice to an active netting cycle.
  """
  use Nexus.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :netting_id, :binary_id
    field :org_id, :binary_id
    field :invoice_id, :binary_id
    field :subsidiary, :string
    field :amount, :decimal
    field :user_id, :binary_id
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:netting_id, :org_id, :invoice_id, :subsidiary, :amount, :user_id])
    |> validate_required([:netting_id, :org_id, :invoice_id, :subsidiary, :amount, :user_id])
  end
end
