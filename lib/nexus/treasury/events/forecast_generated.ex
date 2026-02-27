defmodule Nexus.Treasury.Events.ForecastGenerated do
  @moduledoc """
  Emitted when a new liquidity forecast has been calculated.
  """
  @derive Jason.Encoder
  @enforce_keys [:org_id, :currency, :horizon_days, :predicted_gap, :generated_at]
  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predicted_inflow,
    :predicted_outflow,
    :predicted_gap,
    :generated_at
  ]
end
