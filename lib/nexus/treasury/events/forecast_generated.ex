defmodule Nexus.Treasury.Events.ForecastGenerated do
  @moduledoc """
  Emitted when a new liquidity forecast has been calculated.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          currency: Types.currency(),
          horizon_days: integer(),
          predictions: [map()],
          generated_at: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:org_id, :currency, :horizon_days, :predictions, :generated_at]
  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predictions,
    :generated_at
  ]
end
