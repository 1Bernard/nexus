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
  alias Nexus.Treasury.Events.TransferRequested
  alias Nexus.Payments.Projections.BulkPayment
  import Ecto.Query

  project(%BulkPaymentInitiated{} = ev, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :bulk_payment, %BulkPayment{
      id: ev.bulk_payment_id,
      org_id: ev.org_id,
      user_id: ev.user_id,
      status: "initiated",
      total_items: ev.count,
      processed_items: 0,
      total_amount: ev.total_amount
    })
    |> Ecto.Multi.run(:broadcast, fn _repo, _changes ->
      Phoenix.PubSub.broadcast(
        Nexus.PubSub,
        "payments:bulk_payments:#{ev.org_id}",
        {:bulk_payment_updated, ev}
      )

      {:ok, ev}
    end)
  end)

  project(%TransferRequested{bulk_payment_id: bulk_id} = ev, _metadata, fn multi ->
    if bulk_id do
      query = from(b in BulkPayment, where: b.id == ^bulk_id)

      Ecto.Multi.update_all(multi, :increment_processed, query, inc: [processed_items: 1])
      |> Ecto.Multi.run(:broadcast_progress, fn _repo, _changes ->
        Phoenix.PubSub.broadcast(
          Nexus.PubSub,
          "payments:bulk_payments:updates",
          :bulk_payment_updated
        )

        {:ok, ev}
      end)
    else
      multi
    end
  end)

  project(%BulkPaymentCompleted{} = ev, _metadata, fn multi ->
    query = from(b in BulkPayment, where: b.id == ^ev.bulk_payment_id)

    Ecto.Multi.update_all(multi, :complete_bulk, query, set: [status: "completed"])
    |> Ecto.Multi.run(:broadcast_completion, fn _repo, _changes ->
      Phoenix.PubSub.broadcast(
        Nexus.PubSub,
        "payments:bulk_payments:#{ev.org_id}",
        {:bulk_payment_updated, ev}
      )

      {:ok, ev}
    end)
  end)
end
