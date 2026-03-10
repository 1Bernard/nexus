defmodule Nexus.Payments.Projections.BulkPaymentProcessedTransfer do
  @moduledoc """
  Idempotency table to track which transfers have been counted towards
  a bulk payment's progress.
  """
  use Nexus.Schema

  @primary_key false
  schema "bulk_payment_processed_transfers" do
    field :bulk_payment_id, :binary_id, primary_key: true
    field :transfer_id, :binary_id, primary_key: true

    timestamps(updated_at: false)
  end
end
