defmodule Nexus.Intelligence.Commands.AnalyzeInvoice do
  @moduledoc """
  Command to evaluate an invoice for statistical anomalies.
  """
  @enforce_keys [:analysis_id, :org_id, :invoice_id, :vendor_name, :amount, :currency]
  defstruct [:analysis_id, :org_id, :invoice_id, :vendor_name, :amount, :currency]
end
