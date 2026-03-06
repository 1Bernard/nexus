defmodule Nexus.Treasury.Commands.ApproveReconciliation do
  @derive Jason.Encoder
  defstruct [:org_id, :reconciliation_id, :approver_email, :timestamp]
end
