defmodule Nexus.Treasury.Commands.ApproveReconciliation do
  @moduledoc """
  Command dispatched when an authorised user approves a pending reconciliation proposal.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          approver_email: String.t(),
          timestamp: Types.datetime()
        }
  @enforce_keys [:org_id, :reconciliation_id, :approver_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :approver_email, :timestamp]
end
