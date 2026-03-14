defmodule Nexus.Treasury.Aggregates.Forecast do
  @moduledoc """
  Aggregate for managing cash flow forecasts.
  """
  @derive Jason.Encoder
  defstruct [:id, :org_id, :currency, :last_forecast]

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.Treasury.Events.ForecastGenerated

  def execute(%__MODULE__{} = _state, %GenerateForecast{} = cmd) do
    %ForecastGenerated{
      org_id: cmd.org_id,
      currency: cmd.currency,
      horizon_days: cmd.horizon_days,
      predictions: cmd.predictions,
      generated_at: cmd.generated_at
    }
  end

  def apply(%__MODULE__{} = state, %ForecastGenerated{} = event) do
    %__MODULE__{
      state
      | id: "#{event.org_id}-#{event.currency}-#{event.horizon_days}",
        org_id: event.org_id,
        currency: event.currency,
        last_forecast: event.predictions
    }
  end
end
