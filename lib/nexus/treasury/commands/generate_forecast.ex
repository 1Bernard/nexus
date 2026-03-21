defmodule Nexus.Treasury.Commands.GenerateForecast do
  @moduledoc """
  Command to generate a cash flow forecast for a specific currency and horizon.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          currency: Types.currency(),
          horizon_days: integer(),
          predictions: [map()],
          generated_at: Types.datetime(),
          idempotency_key: String.t()
        }
  @enforce_keys [:org_id, :currency, :horizon_days, :predictions, :generated_at, :idempotency_key]
  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predictions,
    :generated_at,
    :idempotency_key
  ]
end
