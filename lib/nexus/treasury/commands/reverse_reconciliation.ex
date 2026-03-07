defmodule Nexus.Treasury.Commands.ReverseReconciliation do
  @moduledoc """
  Command dispatched when a matched reconciliation must be reversed and both sides
  returned to their unmatched state.
  """
  @enforce_keys [:org_id, :reconciliation_id, :actor_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :actor_email, :timestamp]
end
