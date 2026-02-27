defmodule Nexus.ERP.Aggregates.Invoice do
  @moduledoc """
  The Invoice aggregate handles ingestion and validation of external ERP invoices.
  """
  alias Nexus.ERP.Commands.IngestInvoice
  alias Nexus.ERP.Events.{InvoiceIngested, InvoiceRejected}

  defstruct [:id, :status]

  # Idempotency: If the invoice is already ingested or rejected, we silently accept the duplicate payload
  def execute(%__MODULE__{status: status}, %IngestInvoice{}) when not is_nil(status) do
    []
  end

  # Processing a new invoice
  def execute(%__MODULE__{status: nil}, %IngestInvoice{} = cmd) do
    cond do
      Decimal.compare(Decimal.new(cmd.amount |> to_string()), Decimal.new("0.0")) != :gt ->
        %InvoiceRejected{
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          reason: "Invoice amount must be positive",
          rejected_at: DateTime.utc_now()
        }

      Enum.empty?(List.wrap(cmd.line_items)) ->
        %InvoiceRejected{
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          reason: "Invoice must have at least one line item",
          rejected_at: DateTime.utc_now()
        }

      true ->
        %InvoiceIngested{
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          entity_id: cmd.entity_id,
          currency: cmd.currency,
          amount: cmd.amount,
          subsidiary: cmd.subsidiary,
          line_items: cmd.line_items,
          sap_document_number: cmd.sap_document_number,
          sap_status: cmd.sap_status,
          ingested_at: DateTime.utc_now()
        }
    end
  end

  # State Mutators
  def apply(%__MODULE__{} = state, %InvoiceIngested{} = event) do
    %{state | id: event.invoice_id, status: :ingested}
  end

  def apply(%__MODULE__{} = state, %InvoiceRejected{} = event) do
    %{state | id: event.invoice_id, status: :rejected}
  end
end
