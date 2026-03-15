defmodule Nexus.Treasury.Events.ReconciliationRejected do
  @moduledoc """
  Event emitted when an authorised user rejects a pending reconciliation proposal.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          rejector_email: String.t(),
          timestamp: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:org_id, :reconciliation_id, :rejector_email, :timestamp]
  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
