defmodule Nexus.ERP.Events.InvoiceMatched do
  @moduledoc """
  Event emitted when an invoice is successfully matched.
  """
  @derive Jason.Encoder
  @enforce_keys [:invoice_id, :org_id, :matched_type, :matched_id, :matched_at]
  defstruct [:invoice_id, :org_id, :matched_type, :matched_id, :actor_email, :matched_at]
end
