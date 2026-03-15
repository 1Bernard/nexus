defmodule Nexus.Treasury.Commands.RejectReconciliation do
  @moduledoc """
  Command dispatched when an authorised user rejects a pending reconciliation proposal.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          rejector_email: String.t(),
          timestamp: Types.datetime()
        }
  @enforce_keys [:org_id, :reconciliation_id, :rejector_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
