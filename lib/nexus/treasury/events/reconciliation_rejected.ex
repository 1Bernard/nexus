defmodule Nexus.Treasury.Events.ReconciliationRejected do
  @moduledoc """
  Event emitted when an authorised user rejects a pending reconciliation proposal.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          rejector_email: String.t(),
          timestamp: Types.datetime()
        }

  defstruct [:org_id, :reconciliation_id, :rejector_email, :timestamp]
end
