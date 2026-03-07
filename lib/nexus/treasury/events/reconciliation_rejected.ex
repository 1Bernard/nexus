defmodule Nexus.Treasury.Events.ReconciliationRejected do
  @moduledoc """
  Event emitted when an authorised user rejects a pending reconciliation proposal.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :reconciliation_id, :rejector_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
