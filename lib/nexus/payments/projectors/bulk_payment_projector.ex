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
  alias Nexus.Payments.Projections.BulkPayment
  import Ecto.Query

  project(%BulkPaymentInitiated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :bulk_payment, %BulkPayment{
      id: event.bulk_payment_id,
      org_id: event.org_id,
      user_id: event.user_id,
      status: "initiated",
      total_items: event.count,
      processed_items: 0,
      total_amount: event.total_amount
    })
  end)

  project(%TransferInitiated{bulk_payment_id: bulk_id}, _metadata, fn multi ->
    if bulk_id do
      query = from(b in BulkPayment, where: b.id == ^bulk_id)
      Ecto.Multi.update_all(multi, :increment_processed, query, inc: [processed_items: 1])
    else
      multi
    end
  end)

  project(%BulkPaymentCompleted{} = event, _metadata, fn multi ->
    query = from(b in BulkPayment, where: b.id == ^event.bulk_payment_id)
    Ecto.Multi.update_all(multi, :complete_bulk, query, set: [status: "completed"])
  end)
end
