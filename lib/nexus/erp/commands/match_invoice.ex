defmodule Nexus.ERP.Commands.MatchInvoice do
  @moduledoc """
  Command to match an invoice to a specific payment or bank transaction.
  """
  @enforce_keys [:invoice_id, :org_id, :matched_type, :matched_id]
  defstruct [:invoice_id, :org_id, :matched_type, :matched_id, :actor_email, :matched_at]
end
