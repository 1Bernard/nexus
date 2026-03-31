defmodule Nexus.ERP.Events.InvoiceNetted do
  @moduledoc """
  Event emitted when an invoice has been settled via netting.
  """
  @derive Jason.Encoder
  defstruct [:invoice_id, :org_id, :netting_id, :netted_at]
end
