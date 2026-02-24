defmodule Nexus.ERP.Projections.Invoice do
  @moduledoc """
  Read model for ingested ERP invoices.
  """
  use Nexus.Schema

  schema "erp_invoices" do
    # Explicitly defined for multi-tenancy as per rule
    field :org_id, :binary_id
    field :entity_id, :string
    field :currency, :string
    field :amount, :string
    field :subsidiary, :string
    field :line_items, {:array, :map}
    field :sap_document_number, :string
    field :status, :string, default: "ingested"

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :id,
      :org_id,
      :entity_id,
      :currency,
      :amount,
      :subsidiary,
      :line_items,
      :sap_document_number,
      :status
    ])
    |> validate_required([
      :id,
      :org_id,
      :entity_id,
      :currency,
      :amount,
      :sap_document_number
    ])
  end
end
