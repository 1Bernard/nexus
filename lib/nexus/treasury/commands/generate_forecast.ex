defmodule Nexus.Treasury.Commands.GenerateForecast do
  @moduledoc """
  Command to generate a cash flow forecast for a specific currency and horizon.
  """
  @enforce_keys [:org_id, :currency, :horizon_days, :predictions, :generated_at]
  defstruct [
    :org_id,
    :currency,
    :horizon_days,
    :predictions,
    :generated_at
  ]
end
