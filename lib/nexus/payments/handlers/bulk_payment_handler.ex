defmodule Nexus.Payments.Handlers.BulkPaymentHandler do
  @moduledoc """
  Handles real-time notifications for Bulk Payment events.
  Decoupled from the projector to ensure SRP (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Payments.BulkPaymentHandler",
    consistency: :eventual

  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Payments.Events.BulkPaymentCompleted
  alias Nexus.Treasury.Events.TransferRequested

  def handle(%BulkPaymentInitiated{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "payments:bulk_payments:#{event.org_id}",
      {:bulk_payment_updated, event}
    )

    :ok
  end

  def handle(%TransferRequested{bulk_payment_id: bulk_id}, _metadata) when not is_nil(bulk_id) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "payments:bulk_payments:updates",
      :bulk_payment_updated
    )

    :ok
  end

  def handle(%BulkPaymentCompleted{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "payments:bulk_payments:#{event.org_id}",
      {:bulk_payment_updated, event}
    )

    :ok
  end

  def handle(_event, _metadata), do: :ok
end
