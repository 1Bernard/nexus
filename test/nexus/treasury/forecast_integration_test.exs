defmodule Nexus.Treasury.ForecastIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Treasury
  alias Nexus.Treasury.Projections.ForecastSnapshot
  alias Nexus.ERP.Projections.StatementLine
  alias Nexus.Repo

  @org_id Ecto.UUID.generate()
  @currency "EUR"

  describe "liquidity forecasting" do
    setup do
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
        Nexus.Repo.delete_all(ForecastSnapshot)
        Nexus.Repo.delete_all(StatementLine)
        Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM projection_versions")
      end)

      :ok
    end

    test "successfully generates and projects a forecast based on historical data" do
      # 1. Seed historical statement data (60 days)
      today = Date.utc_today()
      statement_id = Ecto.UUID.generate()

      # Create parent statement
      %Nexus.ERP.Projections.Statement{
        id: statement_id,
        org_id: @org_id,
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
          id: Ecto.UUID.generate(),
          org_id: @org_id,
          statement_id: statement_id,
          date: Date.to_string(date),
          amount: Decimal.new(amount),
          currency: @currency,
          ref: "TEST-#{days_ago}"
        }
        |> Repo.insert!()
      end

      # 2. Trigger forecast
      result = Treasury.generate_forecast(@org_id, @currency, 30, consistency: :eventual)

      assert :ok = result

      # 3. Manually project the event (integration test helper)
      {:ok, [%{data: event, event_number: num}]} =
        Nexus.EventStore.read_stream_forward("forecast-" <> @org_id)

      project_event(
        event,
        num,
        "Treasury.ForecastProjector",
        Nexus.Treasury.Projectors.ForecastProjector
      )

      # 4. Assert projection exists
      snapshot = Repo.one(ForecastSnapshot)
      assert snapshot.org_id == @org_id
      assert snapshot.currency == @currency
      assert length(snapshot.data_points) == 30

      # Verify trend carries through
      [first_pred | _] = snapshot.data_points
      {val, _} = Float.parse(to_string(first_pred["predicted_amount"]))
      assert val < 1010
    end
  end

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      projector_module.handle(event, metadata)
    end)
  end
end
