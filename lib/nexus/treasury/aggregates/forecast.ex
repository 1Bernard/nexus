defmodule Nexus.Treasury.Aggregates.Forecast do
  @moduledoc """
  Aggregate for managing cash flow forecasts.
  """
  @derive Jason.Encoder
  defstruct [:org_id, :currency, :horizon_days, :last_forecast, :last_idempotency_key]

  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.Treasury.Events.ForecastGenerated

  @spec execute(t(), GenerateForecast.t()) :: [struct()] | struct()
  def execute(%__MODULE__{last_idempotency_key: key}, %GenerateForecast{idempotency_key: key})
      when not is_nil(key) do
    # Idempotent success - already processed this exact request
    []
  end

  def execute(%__MODULE__{} = _state, %GenerateForecast{} = cmd) do
    %ForecastGenerated{
      org_id: cmd.org_id,
      currency: cmd.currency,
      horizon_days: cmd.horizon_days,
      predictions: cmd.predictions,
      generated_at: cmd.generated_at,
      idempotency_key: cmd.idempotency_key
    }
  end

  @spec apply(t(), ForecastGenerated.t()) :: t()
  def apply(%__MODULE__{} = state, %ForecastGenerated{} = event) do
    %__MODULE__{
      state
      | org_id: event.org_id,
        currency: event.currency,
        horizon_days: event.horizon_days,
        last_forecast: event.predictions,
        last_idempotency_key: event.idempotency_key
    }
  end
end
