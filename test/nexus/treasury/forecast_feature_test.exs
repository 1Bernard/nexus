defmodule Nexus.Treasury.ForecastFeatureTest do
  @moduledoc """
  Elite BDD tests for Treasury Forecast Dispatch.
  Standardized to Cabbage Gherkin format.
  """
  use Cabbage.Feature, file: "treasury_forecast.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.App

  setup do
    {:ok, %{org_id: Nexus.Schema.generate_uuidv7()}}
  end

  # --- Gherkin Steps ---

  defgiven ~r/^a valid forecast request for "(?<currency>[^"]+)" with "(?<horizon>\d+)" day horizon$/, %{currency: currency, horizon: horizon}, state do
    cmd = %GenerateForecast{
      org_id: state.org_id,
      currency: currency,
      horizon_days: String.to_integer(horizon),
      predictions: [%{date: "2026-04-01", predicted_amount: 50000.0}],
      generated_at: DateTime.utc_now(),
      idempotency_key: "forecast-#{Nexus.Schema.generate_uuidv7()}"
    }
    {:ok, Map.put(state, :cmd, cmd)}
  end

  defwhen ~r/^the command is dispatched to the Nexus ecosystem$/, _, %{cmd: cmd} = state do
    result = App.dispatch(cmd)
    {:ok, Map.put(state, :result, result)}
  end

  defthen ~r/^the dispatch should be accepted and recorded as successful$/, _, %{result: result} = state do
    assert result == :ok
    {:ok, state}
  end
end
