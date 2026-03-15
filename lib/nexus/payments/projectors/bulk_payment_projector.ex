defmodule Nexus.Payments.Projectors.BulkPaymentProjector do
  @moduledoc """
  Projector to sync Bulk Payment events to the read model.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Payments.BulkPaymentProjector",
    repo: Nexus.Repo

  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Payments.Events.BulkPaymentCompleted
  alias Nexus.Treasury.Events.TransferInitiated
  alias Nexus.Payments.Projections.{BulkPayment, BulkPaymentProcessedTransfer}
  import Ecto.Query

  project(%BulkPaymentInitiated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :bulk_payment, %BulkPayment{
      id: event.bulk_payment_id,
      org_id: event.org_id,
      user_id: event.user_id,
      status: "initiated",
      total_items: event.count,
      processed_items: 0,
      total_amount: coerce_to_decimal(event.total_amount)
    })
  end)

  project(
    %TransferInitiated{transfer_id: transfer_id, bulk_payment_id: bulk_id},
    _metadata,
    fn multi ->
      if bulk_id do
        # Idempotency guard: Only increment if this transfer hasn't been counted yet
        # We use a separate table to track this because Ecto.Multi.update_all doesn't support easy multi-table joins for this
        multi
        |> Ecto.Multi.insert(
          {:track_processed, transfer_id},
          %BulkPaymentProcessedTransfer{
            bulk_payment_id: bulk_id,
            transfer_id: transfer_id,
            created_at: Nexus.Schema.utc_now() |> DateTime.truncate(:microsecond)
          },
          on_conflict: :nothing,
          conflict_target: [:bulk_payment_id, :transfer_id]
        )
        |> Ecto.Multi.run({:maybe_increment, transfer_id}, fn repo, changes ->
          if Map.get(changes, {:track_processed, transfer_id}) do
            query = from(b in BulkPayment, where: b.id == ^bulk_id)
            repo.update_all(query, inc: [processed_items: 1])
            {:ok, :incremented}
          else
            {:ok, :skipped_idempotent}
          end
        end)
      else
        multi
      end
    end
  )

  project(%BulkPaymentCompleted{} = event, _metadata, fn multi ->
    query = from(b in BulkPayment, where: b.id == ^event.bulk_payment_id)
    Ecto.Multi.update_all(multi, :complete_bulk, query, set: [status: "completed"])
  end)

  defp coerce_to_decimal(%Decimal{} = d), do: d
  defp coerce_to_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp coerce_to_decimal(_), do: Decimal.new(0)
end
