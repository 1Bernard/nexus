defmodule Nexus.Intelligence.Handlers.InvoiceAnalyzer do
  @moduledoc """
  Listens for `InvoiceIngested` events from the ERP context and triggers
  the intelligence pipeline for anomaly detection.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Intelligence.InvoiceAnalyzer"

  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.Intelligence.Commands.AnalyzeInvoice
  require Logger

  def handle(%InvoiceIngested{} = event, _metadata) do
    Logger.info(
      "[Intelligence] Triggering anomaly detection pipeline for invoice #{event.invoice_id}"
    )

    # Generate a deterministic analysis ID based on the invoice ID
    analysis_id = "anm-" <> String.replace(event.invoice_id, "INV-", "")

    command = %AnalyzeInvoice{
      analysis_id: analysis_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      # Proxying subsidiary as vendor
      vendor_name: event.subsidiary,
      amount: Decimal.new(event.amount),
      currency: event.currency
    }

    case Nexus.App.dispatch(command) do
      :ok ->
        Logger.debug(
          "[Intelligence] AnalyzeInvoice command dispatched successfully for #{event.invoice_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[Intelligence] Failed to dispatch AnalyzeInvoice command: #{inspect(reason)}"
        )

        # We might want to retry or dead-letter in a robust system
        :ok
    end
  end
end
