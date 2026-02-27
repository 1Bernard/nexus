defmodule Nexus.ERP.Events.InvoiceIngested do
  @moduledoc """
  Emitted when an invoice is successfully ingested and validated.
  """
  @derive Jason.Encoder
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
    :sap_status,
    :ingested_at
  ]
end
