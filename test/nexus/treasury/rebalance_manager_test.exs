defmodule Nexus.Treasury.RebalanceManagerTest do
  use ExUnit.Case, async: true
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
    :ok
  end

  test "handle/2 should dispatch RequestTransfer on deficit" do
    org_id = Ecto.UUID.generate()
    event = %ForecastGenerated{
      org_id: org_id,
      currency: "USD",
      horizon_days: 30,
      predictions: [
        %{predicted_amount: "-5000.00", date: "2026-03-22"},
        %{"predicted_amount" => "-5000.00", "date" => "2026-03-23"}
      ],
      generated_at: DateTime.utc_now()
    }

    saga = %RebalanceManager{}
    commands = RebalanceManager.handle(saga, event)

    assert Enum.count(commands) == 1
    [command] = commands
    assert %RequestTransfer{} = command
    assert command.org_id == org_id
    assert command.to_currency == "USD"
    assert command.from_currency == "EUR" # Default source in mock
    assert Decimal.equal?(command.amount, Decimal.new("10000.00"))
  end

  test "handle/2 should not dispatch on surplus" do
    event = %ForecastGenerated{
      org_id: Ecto.UUID.generate(),
      currency: "USD",
      horizon_days: 30,
      predictions: [%{predicted_amount: "5000.00", date: "2026-03-22"}],
      generated_at: DateTime.utc_now()
    }

    saga = %RebalanceManager{}
    assert [] == RebalanceManager.handle(saga, event)
  end
end
