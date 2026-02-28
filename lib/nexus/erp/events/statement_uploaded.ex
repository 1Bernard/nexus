defmodule Nexus.ERP.Events.StatementUploaded do
  @moduledoc """
  Emitted when a bank statement is successfully parsed and accepted.
  Contains the full list of parsed transaction lines for the projector to persist.
  """
  @derive Jason.Encoder
  @enforce_keys [:statement_id, :org_id, :filename, :format, :lines, :uploaded_at]
  defstruct [:statement_id, :org_id, :filename, :format, :lines, :uploaded_at]
end
