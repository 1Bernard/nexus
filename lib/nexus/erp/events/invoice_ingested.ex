defmodule Nexus.ERP.Events.InvoiceIngested do
  @moduledoc """
  Emitted when an invoice is successfully ingested from the ERP system.
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
  @derive Jason.Encoder
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
    :sap_status
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
