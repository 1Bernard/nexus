defmodule Nexus.ERP.Commands.MarkInvoiceAsNetted do
  @moduledoc """
  Command to mark an ERP invoice as settled via netting.
  """
  use Nexus.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :invoice_id, :binary_id
    field :org_id, :binary_id
    field :netting_id, :binary_id
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:invoice_id, :org_id, :netting_id])
    |> validate_required([:invoice_id, :org_id, :netting_id])
  end
end
