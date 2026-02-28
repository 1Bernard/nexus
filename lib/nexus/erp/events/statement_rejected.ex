defmodule Nexus.ERP.Events.StatementRejected do
  @moduledoc """
  Emitted when an uploaded statement file cannot be parsed (empty, wrong format, unreadable).
  """
  @derive Jason.Encoder
  @enforce_keys [:statement_id, :org_id, :reason, :rejected_at]
  defstruct [:statement_id, :org_id, :reason, :rejected_at]
end
