defmodule Nexus.Treasury.Commands.RejectReconciliation do
  @moduledoc """
  Command dispatched when an authorised user rejects a pending reconciliation proposal.
  """
  @enforce_keys [:org_id, :reconciliation_id, :rejector_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
