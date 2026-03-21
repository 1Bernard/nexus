defmodule Nexus.Intelligence.Commands.AnalyzeReconciliation do
  @moduledoc """
  Command to evaluate a reconciliation for high variance.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          analysis_id: Types.binary_id(),
          org_id: Types.org_id(),
          reconciliation_id: Types.binary_id(),
          variance: Types.money(),
          currency: Types.currency(),
          flagged_at: Types.datetime()
        }

  @enforce_keys [
    :analysis_id,
    :org_id,
    :reconciliation_id,
    :variance,
    :currency,
    :flagged_at
  ]
  defstruct [
    :analysis_id,
    :org_id,
    :reconciliation_id,
    :variance,
    :currency,
    :flagged_at
  ]
end
