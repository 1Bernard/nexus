defmodule Nexus.Payments.Projections.BulkPayment do
  @moduledoc """
  Read model for Bulk Payment batches.
  """
  use Nexus.Schema

  @derive Jason.Encoder
  schema "payments_bulk_payments" do
    field :org_id, :binary_id
    field :user_id, :binary_id
    field :status, :string
    field :total_items, :integer
    field :processed_items, :integer, default: 0
    field :total_amount, :decimal

    timestamps()
  end
end
