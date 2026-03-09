defmodule Nexus.ERP.Handlers.ERPNotificationHandler do
  @moduledoc """
  Handles real-time PubSub notifications for ERP domain events.
  Decoupled from InvoiceProjector (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "ERP.Handlers.ERPNotificationHandler",
    consistency: :eventual

  alias Nexus.ERP.Events.{InvoiceIngested, StatementUploaded, StatementRejected}

  def handle(%InvoiceIngested{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "erp_invoices:#{event.org_id}",
      {:invoice_ingested, event.invoice_id}
    )

    :ok
  end

  def handle(%StatementUploaded{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "erp_statements:#{event.org_id}",
      {:statement_uploaded, event.statement_id}
    )

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
end
