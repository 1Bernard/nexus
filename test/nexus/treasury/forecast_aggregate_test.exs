defmodule Nexus.Treasury.ForecastAggregateTest do
  use ExUnit.Case, async: true
  alias Nexus.Treasury.Aggregates.Forecast
  alias Nexus.Treasury.Events.ForecastGenerated

  test "apply/2 should correctly update state without crashing" do
    state = %Forecast{}
    event = %ForecastGenerated{
      org_id: Ecto.UUID.generate(),
      currency: "EUR",
      horizon_days: 30,
      predictions: [%{date: "2026-03-03", predicted_amount: "641.86"}],
      generated_at: DateTime.utc_now()
    }

    new_state = Forecast.apply(state, event)

    # Verify Jason encoding (Commanded uses this for snapshots)
    assert {:ok, _json} = Jason.encode(new_state)

    assert new_state.org_id == event.org_id
    assert new_state.currency == event.currency
    assert new_state.horizon_days == event.horizon_days
    assert new_state.last_forecast == event.predictions
  end
end
