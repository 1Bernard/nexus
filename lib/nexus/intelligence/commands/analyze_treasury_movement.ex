defmodule Nexus.Intelligence.Commands.AnalyzeTreasuryMovement do
  @moduledoc """
  Command to evaluate a treasury transfer for statistical anomalies.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          transfer_id: Types.binary_id(),
          amount: Types.money(),
          currency: Types.currency(),
          flagged_at: Types.datetime()
        }

  @enforce_keys [
    :analysis_id,
    :org_id,
    :transfer_id,
    :amount,
    :currency,
    :flagged_at
  ]
  defstruct [
    :analysis_id,
    :org_id,
    :transfer_id,
    :amount,
    :currency,
    :flagged_at
  ]
end
