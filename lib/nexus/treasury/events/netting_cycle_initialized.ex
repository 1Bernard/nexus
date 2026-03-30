defmodule Nexus.Treasury.Events.NettingCycleInitialized do
  @moduledoc """
  Emitted when a new netting cycle has been started for an organization and currency.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [
    :netting_id,
    :org_id,
    :currency,
    :period_start,
    :period_end,
    :user_id,
    :initialized_at
  ]

  @type t :: %__MODULE__{
          netting_id: Types.binary_id(),
          org_id: Types.org_id(),
          currency: Types.currency(),
          period_start: Types.datetime(),
          period_end: Types.datetime(),
          user_id: Types.binary_id(),
          initialized_at: Types.datetime()
        }
end
