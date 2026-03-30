defmodule Nexus.Treasury.ForecastIntegrationFeatureTest do
  @moduledoc false
  use Cabbage.Feature, file: "treasury/forecast_generation.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury
  alias Nexus.Treasury.Projections.ForecastSnapshot
  alias Nexus.ERP.Projections.StatementLine
  alias Nexus.Repo

  setup do
    org_id = Nexus.Schema.generate_uuidv7()
    currency = "EUR"

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(ForecastSnapshot)
      Nexus.Repo.delete_all(StatementLine)
      Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM projection_versions")
    end)

    {:ok, %{org_id: org_id, currency: currency}}
  end

  # --- Given ---

  defgiven ~r/^a treasury department with 60 days of historical statement data in "(?<currency>[^"]+)"$/,
           %{currency: currency},
           state do
    unboxed_run(fn ->
      today = Date.utc_today()
      statement_id = Nexus.Schema.generate_uuidv7()

      # Create parent statement
      %Nexus.ERP.Projections.Statement{
        id: statement_id,
        org_id: state.org_id,
        filename: "test.csv",
        format: "CSV",
        status: "uploaded",
        line_count: 60,
        uploaded_at: DateTime.utc_now()
      }
      |> Repo.insert!()

      # Seed data with a trend: increasing cash flow
      for days_ago <- 60..1//-1 do
        date = Date.add(today, -days_ago)
        amount = 1000 + days_ago * 10

        %StatementLine{
          id: Nexus.Schema.generate_uuidv7(),
          org_id: state.org_id,
          statement_id: statement_id,
          date: Date.to_string(date),
          amount: Decimal.new(amount),
          currency: currency,
          ref: "TEST-#{days_ago}"
        }
        |> Repo.insert!()
      end
    end)

    {:ok, Map.put(state, :currency, currency)}
  end

  # --- When ---

  defwhen ~r/^I request a liquidity forecast for the next 30 days$/, _vars, state do
    result =
      unboxed_run(fn ->
        Treasury.generate_forecast(state.org_id, state.currency, 30, consistency: :eventual)
      end)

    assert :ok = result
    {:ok, state}
  end

  defwhen ~r/^the forecast event is projected into the read model$/, _vars, state do
    # Manual projection for determinism
    {:ok, [%{data: event, event_number: num}]} =
      Nexus.EventStore.read_stream_forward("forecast-" <> state.org_id <> "-" <> state.currency)

    project_event(
      event,
      num,
      "Treasury.ForecastProjector",
      Nexus.Treasury.Projectors.ForecastProjector
    )

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^I should see a 30-day forecast snapshot in the read model$/, _vars, state do
    snapshot =
      unboxed_run(fn ->
        Repo.one(ForecastSnapshot)
      end)

    assert snapshot.org_id == state.org_id
    assert snapshot.currency == state.currency
    assert length(snapshot.data_points) == 30
    {:ok, Map.put(state, :snapshot, snapshot)}
  end

  defthen ~r/^the predicted amounts should reflect a consistent trend$/, _vars, state do
    [first_pred | _] = state.snapshot.data_points
    {val, _} = Float.parse(to_string(first_pred["predicted_amount"]))
    assert val < 1010
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      projector_module.handle(event, metadata)
    end)
  end
end
