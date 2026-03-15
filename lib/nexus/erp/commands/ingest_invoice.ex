defmodule Nexus.ERP.Commands.IngestInvoice do
  @moduledoc """
  Command to ingest a new invoice from an external ERP system (e.g., SAP).
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          invoice_id: Types.binary_id(),
          entity_id: String.t(),
          currency: Types.currency(),
          amount: Types.money(),
          due_date: String.t(),
          subsidiary: String.t(),
          line_items: [map()],
          sap_document_number: String.t(),
          sap_status: String.t(),
          ingested_at: Types.datetime()
        }
  @enforce_keys [
    :org_id,
    :invoice_id,
    :entity_id,
    :currency,
    :amount,
    :due_date,
    :subsidiary,
    :line_items,
    :sap_document_number,
    :sap_status,
    :ingested_at
  ]
  defstruct [
    :org_id,
    :invoice_id,
    :entity_id,
    :currency,
    :amount,
    :due_date,
    :subsidiary,
    :line_items,
    :sap_document_number,
    :sap_status,
    :ingested_at
  ]
end
