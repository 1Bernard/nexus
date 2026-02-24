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
    :sap_document_number
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
    :ingested_at
  ]
end
