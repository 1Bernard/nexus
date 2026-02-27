defmodule Nexus.ERP.Commands.IngestInvoice do
  @moduledoc """
  Command to ingest a new invoice from an external ERP system (e.g., SAP).
  """
  @enforce_keys [
    :org_id,
    :invoice_id,
    :entity_id,
    :currency,
    :amount,
    :subsidiary,
    :line_items,
    :sap_document_number,
    :sap_status
  ]
  defstruct [
    :org_id,
    :invoice_id,
    :entity_id,
    :currency,
    :amount,
    :subsidiary,
    :line_items,
    :sap_document_number,
    :sap_status
  ]
end
