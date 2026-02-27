defmodule Nexus.Treasury.Commands.GenerateForecast do
  @moduledoc """
  Command to generate a cash flow forecast for a specific currency and horizon.
  """
  @enforce_keys [:org_id, :currency, :horizon_days, :predicted_gap]
  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predicted_inflow,
    :predicted_outflow,
    :predicted_gap
  ]
end
