defmodule Nexus.Treasury.Commands.ReverseReconciliation do
  @moduledoc """
  Command dispatched when a matched reconciliation must be reversed and both sides
  returned to their unmatched state.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          actor_email: String.t() | nil,
          timestamp: Types.datetime()
        }
  @enforce_keys [:org_id, :reconciliation_id, :actor_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :actor_email, :timestamp]
end
