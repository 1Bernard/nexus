defmodule Nexus.Treasury.ForecastDispatchTest do
  use ExUnit.Case

  alias Nexus.Treasury.Commands.GenerateForecast
  alias Nexus.App

  @tag timeout: :infinity
  test "dispatches the forecast command without crashing the aggregate" do
    # Requires the live system to be running for EventStore connection if we use --no-start
    # But we will use the test environment with a pure App start
    cmd = %GenerateForecast{
      org_id: "00000000-0000-0000-0000-000000000000",
      currency: "EUR",
      horizon_days: 30,
      predictions: [%{date: "2026-03-03", predicted_amount: 1000.5}]
    }

    IO.puts("\n=== DISPATCHING MOCK COMMAND ===")
    result = App.dispatch(cmd)
    IO.inspect(result, label: "DISPATCH RESULT", structs: false)

    assert result == :ok
  end
end
