defmodule Nexus.Treasury.Commands.RejectReconciliation do
  @derive Jason.Encoder
  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
