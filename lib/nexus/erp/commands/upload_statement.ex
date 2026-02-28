defmodule Nexus.ERP.Commands.UploadStatement do
  @moduledoc """
  Command to upload a bank statement file for parsing and reconciliation.
  Supported formats: "mt940" (SWIFT MT940), "csv" (4-column: date, ref, amount, currency, narrative).
  """
  @enforce_keys [:statement_id, :org_id, :filename, :format, :raw_content]
  defstruct [:statement_id, :org_id, :filename, :format, :raw_content]
end
