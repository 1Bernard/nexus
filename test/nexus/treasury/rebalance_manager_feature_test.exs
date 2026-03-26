defmodule Nexus.Treasury.RebalanceManagerFeatureTest do
  use Cabbage.Feature, file: "treasury/rebalance_manager.feature"
  use Nexus.DataCase

  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Commands.RequestTransfer

  defmodule VaultQueryMock do
    def find_vault_for_currency(_org_id, "EUR"), do: %{id: "vault-eur-123"}
    def find_vault_for_currency(_org_id, _), do: nil
  end

  setup do
    Application.put_env(:nexus, :vault_query_module, VaultQueryMock)
    on_exit(fn -> Application.delete_env(:nexus, :vault_query_module) end)

    {:ok, %{org_id: Nexus.Schema.generate_uuidv7()}}
  end

  # --- Given ---

  defgiven ~r/^a forecast is generated for "(?<currency>[^"]+)" with a deficit of "(?<amount>[^"]+)"$/,
           %{currency: currency, amount: amount},
           state do
    event = %ForecastGenerated{
      org_id: state.org_id,
      currency: currency,
      horizon_days: 30,
      predictions: [
        %{predicted_amount: "-#{amount}", date: "2026-03-22"}
      ],
      generated_at: DateTime.utc_now()
    }
    {:ok, Map.put(state, :forecast_event, event)}
  end

  defgiven ~r/^a forecast is generated for "(?<currency>[^"]+)" with a surplus of "(?<amount>[^"]+)"$/,
           %{currency: currency, amount: amount},
           state do
    event = %ForecastGenerated{
      org_id: state.org_id,
      currency: currency,
      horizon_days: 30,
      predictions: [
        %{predicted_amount: "#{amount}", date: "2026-03-22"}
      ],
      generated_at: DateTime.utc_now()
    }
    {:ok, Map.put(state, :forecast_event, event)}
  end

  # --- When ---

  defwhen ~r/^the Rebalance Manager handles the forecast$/, _vars, state do
    saga = %RebalanceManager{}
    commands = RebalanceManager.handle(saga, state.forecast_event)
    {:ok, Map.put(state, :commands, commands)}
  end

  # --- Then ---

  defthen ~r/^a "RequestTransfer" command should be dispatched for "(?<amount>[^"]+)" (?<currency>[^"]+) from "(?<source>[^"]+)"$/,
          %{amount: amount, currency: currency, source: source},
          state do
    assert Enum.count(state.commands) == 1
    [command] = state.commands
    assert %RequestTransfer{} = command
    assert command.to_currency == currency
    assert command.from_currency == source
    assert Decimal.equal?(command.amount, Decimal.new(amount))
    {:ok, state}
  end

  defthen ~r/^no "RequestTransfer" command should be dispatched$/, _vars, state do
    assert state.commands == []
    {:ok, state}
  end
end
