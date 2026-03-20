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
    %TransferInitiated{transfer_id: transfer_id, bulk_payment_id: bulk_id, org_id: org_id},
    _metadata,
    fn multi ->
      case bulk_id do
        nil ->
          multi

        bulk_id ->
          # Idempotency guard: Only increment if this transfer hasn't been counted yet
          multi
          |> Ecto.Multi.insert(
            {:track_processed, transfer_id},
            %BulkPaymentProcessedTransfer{
              bulk_payment_id: bulk_id,
              transfer_id: transfer_id,
              org_id: org_id,
              created_at: Nexus.Schema.utc_now() |> DateTime.truncate(:microsecond)
            },
            on_conflict: :nothing,
            conflict_target: [:bulk_payment_id, :transfer_id]
          )
          |> Ecto.Multi.run({:maybe_increment, transfer_id}, fn repo, changes ->
            maybe_increment_processed(repo, changes, bulk_id, transfer_id)
          end)
      end
    end
  )

  defp maybe_increment_processed(repo, changes, bulk_id, transfer_id) do
    case Map.get(changes, {:track_processed, transfer_id}) do
      nil ->
        {:ok, :skipped_idempotent}

      processed_record ->
        query =
          from(b in BulkPayment, where: b.id == ^bulk_id and b.org_id == ^processed_record.org_id)

        repo.update_all(query, inc: [processed_items: 1])
        {:ok, :incremented}
    end
  end

  project(%BulkPaymentCompleted{} = event, _metadata, fn multi ->
    query =
      from(b in BulkPayment, where: b.id == ^event.bulk_payment_id and b.org_id == ^event.org_id)

    Ecto.Multi.update_all(multi, :complete_bulk, query, set: [status: "completed"])
  end)

  defp coerce_to_decimal(%Decimal{} = d), do: d
  defp coerce_to_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp coerce_to_decimal(_), do: Decimal.new(0)
end
