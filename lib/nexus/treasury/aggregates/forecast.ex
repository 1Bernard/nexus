defmodule Nexus.Treasury.Aggregates.Forecast do
  @moduledoc """
  Aggregate for managing cash flow forecasts.
  """
  defstruct [:id, :org_id, :currency, :last_forecast]

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.Treasury.Events.ForecastGenerated

  def execute(%__MODULE__{} = _state, %GenerateForecast{} = cmd) do
    %ForecastGenerated{
      org_id: cmd.org_id,
      currency: cmd.currency,
      horizon_days: cmd.horizon_days,
      predictions: cmd.predictions,
      generated_at: DateTime.utc_now()
    }
  end

  def apply(%__MODULE__{} = state, %ForecastGenerated{} = ev) do
    %__MODULE__{
      state
      | id: "#{ev.org_id}-#{ev.currency}-#{ev.horizon_days}",
        org_id: ev.org_id,
        currency: ev.currency,
        last_forecast: ev.predictions
    }
  end
end
