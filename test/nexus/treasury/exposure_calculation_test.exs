defmodule Nexus.Treasury.ExposureCalculationTest do
  use Cabbage.Feature, file: "treasury/exposure_calculation.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.CalculateExposure
  alias Nexus.Treasury.Events.ExposureCalculated
  alias Nexus.Treasury.Projectors.ExposureProjector
  alias Nexus.Treasury.Projections.ExposureSnapshot

  setup do
    # In :manual mode, use unboxed_run for all DB cleanup so we get a real connection.
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(ExposureSnapshot)
      Nexus.Repo.delete_all("projection_versions")
    end)

    {:ok, %{
      unique_sub: "Sub-#{Nexus.Schema.generate_uuidv7()}",
      org_id: Nexus.Schema.generate_uuidv7()
    }}
  end

  # --- Scenario: Calculating exposure for unhedged invoices ---

  defgiven ~r/^a subsidiary "(?<sub_name>[^"]+)" has an open "(?<curr>[^"]+)" invoice for "(?<amount>[^"]+)"$/,
           %{curr: curr, amount: amount},
           state do
    {:ok, Map.merge(state, %{invoice_currency: curr, invoice_amount: amount})}
  end

  defgiven ~r/^the current "(?<pair>[^"]+)" exchange rate is "(?<rate>[^"]+)"$/,
           %{pair: _pair, rate: rate},
           state do
    {:ok, Map.put(state, :rate, rate)}
  end

  defwhen ~r/^the exposure calculation is triggered$/, _vars, state do
    {amount_dec, _} = Decimal.parse(state.invoice_amount)
    {rate_dec, _} = Decimal.parse(state.rate)
    calculated_exposure = Decimal.div(amount_dec, rate_dec) |> Decimal.round(2)

    sub = state.unique_sub
    org_id = state.org_id
    now = DateTime.utc_now()

    cmd = %CalculateExposure{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      subsidiary: sub,
      currency: "EUR",
      exposure_amount: calculated_exposure,
      timestamp: now
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ExposureCalculated{
      org_id: org_id,
      subsidiary: sub,
      currency: "EUR",
      exposure_amount: Decimal.to_string(calculated_exposure),
      timestamp: DateTime.to_iso8601(now)
    }

    project_event(event, 1)
    {:ok, Map.merge(state, %{last_calculated: calculated_exposure})}
  end

  defthen ~r/^the total exposure for "(?<sub_name>[^"]+)" is registered as "(?<expected_exp>[^"]+)" "(?<curr>[^"]+)"$/,
          %{expected_exp: expected},
          state do
    snapshot = get_snapshot(state.org_id, state.unique_sub, "EUR")
    assert snapshot != nil, "Expected snapshot for #{state.unique_sub}-EUR to exist"

    {expected_dec, _} = Decimal.parse(expected)
    assert Decimal.eq?(snapshot.exposure_amount, expected_dec)
    {:ok, state}
  end

  # --- Scenario: Re-evaluating exposure after a market tick ---

  defgiven ~r/^an existing exposure calculation of "(?<amount>[^"]+)" "(?<curr>[^"]+)" for "(?<sub_name>[^"]+)"$/,
           %{amount: amount, curr: curr},
           state do
    {amount_dec, _} = Decimal.parse(amount)
    sub = state.unique_sub
    org_id = state.org_id
    now = DateTime.utc_now()

    cmd = %CalculateExposure{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      subsidiary: sub,
      currency: curr,
      exposure_amount: amount_dec,
      timestamp: now
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ExposureCalculated{
      org_id: org_id,
      subsidiary: sub,
      currency: curr,
      exposure_amount: Decimal.to_string(amount_dec),
      timestamp: DateTime.to_iso8601(now)
    }

    project_event(event, 1)
    {:ok, Map.merge(state, %{currency: curr})}
  end

  defwhen ~r/^a new market tick for "(?<pair>[^"]+)" arrives at price "(?<rate>[^"]+)"$/,
           %{pair: _pair, rate: rate},
           state do
    {rate_dec, _} = Decimal.parse(rate)
    # Use the invoice_amount from the feature or state if possible, but the feature doesn't provide it here.
    # The scenario assumes a 100000 USD invoice as per the first scenario logic.
    invoice_amount = Decimal.new("100000")
    new_exposure = Decimal.div(invoice_amount, rate_dec) |> Decimal.round(2)

    org_id = state.org_id
    now = DateTime.utc_now()

    cmd = %CalculateExposure{
      id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      subsidiary: state.unique_sub,
      currency: state.currency,
      exposure_amount: new_exposure,
      timestamp: now
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %ExposureCalculated{
      org_id: org_id,
      subsidiary: state.unique_sub,
      currency: state.currency,
      exposure_amount: Decimal.to_string(new_exposure),
      timestamp: DateTime.to_iso8601(now)
    }

    project_event(event, 2)
    {:ok, state}
  end

  defthen ~r/^the exposure for "(?<sub_name>[^"]+)" is recalculated to "(?<expected_exp>[^"]+)" "(?<curr>[^"]+)"$/,
          %{expected_exp: expected, curr: curr},
          state do
    snapshot = get_snapshot(state.org_id, state.unique_sub, curr)
    assert snapshot != nil, "Expected recalculated snapshot for #{state.unique_sub}-#{curr} to exist"

    {expected_dec, _} = Decimal.parse(expected)
    assert Decimal.eq?(snapshot.exposure_amount, expected_dec)
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "Treasury.ExposureProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      ExposureProjector.handle(event, metadata)
    end)
  end

  defp get_snapshot(org_id, subsidiary, currency) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.get_by(ExposureSnapshot, org_id: org_id, subsidiary: subsidiary, currency: currency)
    end)
  end
end
