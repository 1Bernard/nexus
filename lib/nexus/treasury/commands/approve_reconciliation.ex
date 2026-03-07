defmodule Nexus.Treasury.Commands.ApproveReconciliation do
  @moduledoc """
  Command dispatched when an authorised user approves a pending reconciliation proposal.
  """
  @enforce_keys [:org_id, :reconciliation_id, :approver_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :approver_email, :timestamp]
end
