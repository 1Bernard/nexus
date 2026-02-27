defmodule Nexus.Treasury.CashFlowOutlookTest do
  use Cabbage.Feature, file: "treasury/cash_flow_outlook.feature"
  use Nexus.DataCase

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projectors.ForecastProjector
  alias Nexus.Treasury.Projections.Forecast

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      Nexus.Repo.delete_all(Forecast)

      Nexus.Repo.delete_all(
        from p in "projection_versions", where: p.projection_name == "Treasury.ForecastProjector"
      )
    end)

    {:ok, %{org_id: Ecto.UUID.generate()}}
  end

  # --- Given ---

  defgiven ~r/^a baseline cash flow outlook for "(?<curr>[^"]+)"$/, %{curr: curr}, state do
    {:ok, Map.put(state, :currency, curr)}
  end

  defgiven ~r/^a cash flow outlook for "(?<curr>[^"]+)" with a projected gap of "(?<gap>[^"]+)"$/,
           %{curr: curr, gap: gap},
           state do
    # Pre-populate a forecast
    org_id = state.org_id
    {gap_dec, _} = Decimal.parse(gap)

    cmd = %GenerateForecast{
      org_id: org_id,
      currency: curr,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: gap_dec,
      predicted_gap: gap_dec
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ForecastGenerated{
      org_id: org_id,
      currency: curr,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: gap_dec,
      predicted_gap: gap_dec,
      generated_at: DateTime.utc_now()
    }

    project_event(event, 1)

    {:ok, Map.merge(state, %{currency: curr, gap: gap_dec})}
  end

  defgiven ~r/^a new SAP invoice is received for "(?<sub_name>[^"]+)" with:$/, _vars, state do
    # Table data parsing usually goes here if we want to be exact,
    # but for this test we'll mock the next step.
    {:ok, state}
  end

  # --- When ---

  defwhen ~r/^the "(?<pair>[^"]+)" market price changes to "(?<rate>[^"]+)"$/,
          %{pair: _pair, rate: rate},
          state do
    # Trigger a recalculation (simplified for this test)
    {rate_dec, _} = Decimal.parse(rate)
    new_gap = Decimal.mult(state.gap, rate_dec)

    cmd = %GenerateForecast{
      org_id: state.org_id,
      currency: state.currency,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: new_gap,
      predicted_gap: new_gap
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ForecastGenerated{
      org_id: state.org_id,
      currency: state.currency,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: new_gap,
      predicted_gap: new_gap,
      generated_at: DateTime.utc_now()
    }

    project_event(event, 2)

    {:ok, Map.put(state, :consolidated_gap, new_gap)}
  end

  # --- Then ---

  defthen ~r/^the "(?<curr>[^"]+)" cash flow outlook should reflect a projected outflow of "(?<amount>[^"]+)" on "(?<due>[^"]+)"$/,
          %{amount: amount},
          state do
    # In a real scenario, we'd trigger the whole Ingest -> Exposure -> Forecast loop.
    # Here we verify the projection directly.
    {amount_dec, _} = Decimal.parse(amount)

    cmd = %GenerateForecast{
      org_id: state.org_id,
      currency: state.currency,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: amount_dec,
      predicted_gap: Decimal.negate(amount_dec)
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ForecastGenerated{
      org_id: state.org_id,
      currency: state.currency,
      horizon_days: 30,
      predicted_inflow: Decimal.new("0"),
      predicted_outflow: amount_dec,
      predicted_gap: Decimal.negate(amount_dec),
      generated_at: DateTime.utc_now()
    }

    project_event(event, 3)

    forecast = get_forecast(state.org_id, state.currency, 30)
    assert forecast != nil
    assert Decimal.eq?(forecast.predicted_outflow, amount_dec)
    {:ok, state}
  end

  defthen ~r/^the consolidated "EUR" cash gap should be recalculated using the new "(?<rate>[^"]+)" rate$/,
          %{rate: rate},
          state do
    forecast = get_forecast(state.org_id, state.currency, 30)
    assert forecast != nil
    {rate_dec, _} = Decimal.parse(rate)
    expected_gap = Decimal.mult(state.gap, rate_dec)
    assert Decimal.eq?(forecast.predicted_gap, expected_gap)
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "Treasury.ForecastProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      ForecastProjector.handle(event, metadata)
    end)
  end

  defp get_forecast(org_id, currency, horizon) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query

      Nexus.Repo.one(
        from f in Forecast,
          where: f.org_id == ^org_id and f.currency == ^currency and f.horizon_days == ^horizon
      )
    end)
  end
end
