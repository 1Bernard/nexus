defmodule Nexus.ERP.Aggregates.Invoice do
  @moduledoc """
  The Invoice aggregate handles ingestion and validation of external ERP invoices.
  """
  alias Nexus.ERP.Commands.{IngestInvoice, MatchInvoice}
  alias Nexus.ERP.Events.{InvoiceIngested, InvoiceRejected, InvoiceMatched}

  @derive Jason.Encoder
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
          rejected_at: cmd.ingested_at
        }

      Enum.empty?(List.wrap(cmd.line_items)) ->
        %InvoiceRejected{
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          reason: "Invoice must have at least one line item",
          rejected_at: cmd.ingested_at
        }

      true ->
        %InvoiceIngested{
          org_id: cmd.org_id,
          invoice_id: cmd.invoice_id,
          entity_id: cmd.entity_id,
          currency: cmd.currency,
          amount: cmd.amount,
          due_date: cmd.due_date,
          subsidiary: cmd.subsidiary,
          line_items: cmd.line_items,
          sap_document_number: cmd.sap_document_number,
          sap_status: cmd.sap_status,
          ingested_at: cmd.ingested_at
        }
    end
  end

  # Matching an invoice (idempotent if already matched to the same thing)
  def execute(%__MODULE__{status: :matched, id: id}, %MatchInvoice{invoice_id: id}) do
    []
  end

  def execute(%__MODULE__{status: :ingested}, %MatchInvoice{} = cmd) do
    %InvoiceMatched{
      invoice_id: cmd.invoice_id,
      org_id: cmd.org_id,
      matched_type: cmd.matched_type,
      matched_id: cmd.matched_id,
      actor_email: cmd.actor_email,
      matched_at: cmd.matched_at || Nexus.Schema.utc_now()
    }
  end

  # Fallback for MatchInvoice if status is nil or rejected
  def execute(%__MODULE__{}, %MatchInvoice{}) do
    # For now, we ignore matching if the invoice isn't in a valid state
    # In a production system, we might raise an error or queue for retry
    []
  end

  # State Mutators
  def apply(%__MODULE__{} = state, %InvoiceIngested{} = event) do
    %{state | id: event.invoice_id, status: :ingested}
  end

  def apply(%__MODULE__{} = state, %InvoiceRejected{} = event) do
    %{state | id: event.invoice_id, status: :rejected}
  end

  def apply(%__MODULE__{} = state, %InvoiceMatched{} = event) do
    %{state | id: event.invoice_id, status: :matched}
  end
end
