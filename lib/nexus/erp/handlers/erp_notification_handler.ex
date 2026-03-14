defmodule Nexus.ERP.Handlers.ERPNotificationHandler do
  @moduledoc """
  Handles real-time PubSub notifications for ERP domain events AND
  publishes volatile Webhook payloads to RabbitMQ.

  Industry Standard: NEVER make synchronous HTTP calls (Webhooks) from an
  EventSourced Handler. If the webhook fails, the handler crashes and
  blocks the entire projection stream. Instead, we publish to RabbitMQ,
  which is designed for volatile queues and guaranteed delivery.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "ERP.Handlers.ERPNotificationHandler",
    consistency: :eventual

  alias Nexus.ERP.Events.{InvoiceIngested, StatementUploaded, StatementRejected}

  # For production, you would run a persistent connection pool.
  # For learning/demo, we open a transient connection per handle.
  @rabbitmq_url "amqp://guest:guest@localhost"
  @webhook_exchange "erp_webhooks"

  def handle(%InvoiceIngested{} = event, _metadata) do
    # 1. UI Reactivity: Notify LiveViews instantly
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "erp_invoices:#{event.org_id}",
      {:invoice_ingested, event.invoice_id}
    )

    # 2. Async Integration: Queue Webhook payload for external SAP system
    payload =
      Jason.encode!(%{
        webhook_type: "invoice.ingested",
        org_id: event.org_id,
        invoice_id: event.invoice_id,
        entity_id: event.entity_id,
        timestamp: DateTime.utc_now()
      })

    publish_to_rabbitmq(payload)

    :ok
  end

  def handle(%StatementUploaded{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "erp_statements:#{event.org_id}",
      {:statement_uploaded, event.statement_id}
    )

    payload =
      Jason.encode!(%{
        webhook_type: "statement.uploaded",
        org_id: event.org_id,
        statement_id: event.statement_id,
        filename: event.filename,
        timestamp: DateTime.utc_now()
      })

    publish_to_rabbitmq(payload)

    :ok
  end

  def handle(%StatementRejected{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "erp_statements:#{event.org_id}",
      {:statement_rejected, event.statement_id}
    )

    :ok
  end

  def handle(_event, _metadata), do: :ok

  # --- Private Message Broker Infrastructure ---

  defp publish_to_rabbitmq(json_payload) do
    # In a full-scale app, Connection/Channel is managed by a long-running GenServer pool
    with {:ok, conn} <- AMQP.Connection.open(@rabbitmq_url),
         {:ok, chan} <- AMQP.Channel.open(conn) do
      # Ensure exchange exists (Fanout is perfect for webhooks being consumed by multiple workers)
      :ok = AMQP.Exchange.fanout(chan, @webhook_exchange, durable: true)

      # Publish (Safe failure boundary)
      :ok = AMQP.Basic.publish(chan, @webhook_exchange, "", json_payload, persistent: true)

      AMQP.Connection.close(conn)
    else
      {:error, reason} ->
        # We catch the error instead of raising. Even if RabbitMQ is down,
        # we do NOT want our EventStore handler to crash. We would log this in CloudWatch.
        require Logger

        Logger.error(
          "Failed to publish Webhook to RabbitMQ: #{inspect(reason)}. Payload: #{json_payload}"
        )
    end
  end
end
