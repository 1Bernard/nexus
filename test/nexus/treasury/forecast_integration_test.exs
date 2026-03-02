defmodule Nexus.Treasury.ForecastIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Treasury
  alias Nexus.Treasury.Projections.ForecastSnapshot
  alias Nexus.ERP.Projections.StatementLine

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
      for i <- 60..1 do
        date = Date.add(today, -i)
        # Upward trend
        amount = 1000 + i * 10

        %StatementLine{
          id: Ecto.UUID.generate(),
          org_id: @org_id,
          statement_id: statement_id,
          date: Date.to_string(date),
          amount: Decimal.new(amount),
          currency: @currency,
          ref: "TEST-#{i}"
        }
        |> Repo.insert!()
      end

      # 2. Trigger forecast
      result = Treasury.generate_forecast(@org_id, @currency, 30)
      IO.inspect(result, label: "FORECAST RESULT")
      :ok = result

      # 3. Manually project the event
      {:ok, [%{data: event, event_number: num}]} =
        Nexus.EventStore.read_stream_forward(@org_id)

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

      # Verify downward trend carries through (prediction < last historical point)
      # Oldest was 1600, newest was 1010, next should be 1000 or 990.
      [first_pred | _] = snapshot.data_points
      assert first_pred["predicted_amount"] < 1010
    end
  end

  defp project_event(event, event_number, handler_name, projector_module) do
    metadata = %{handler_name: handler_name, event_number: event_number}

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Ecto.Adapters.SQL.query!(Nexus.Repo, "DELETE FROM projection_versions")
      projector_module.handle(event, metadata)
    end)
  end
end
