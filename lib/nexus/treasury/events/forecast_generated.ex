defmodule Nexus.Treasury.Events.ForecastGenerated do
  @moduledoc """
  Emitted when a new liquidity forecast has been calculated.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          currency: Types.currency(),
          horizon_days: integer(),
          predictions: [map()],
          generated_at: Types.datetime()
        }

  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predictions,
    :generated_at
  ]
end
