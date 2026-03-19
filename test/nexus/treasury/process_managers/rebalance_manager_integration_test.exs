defmodule Nexus.Treasury.ProcessManagers.RebalanceManagerIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.Vault
  alias Nexus.Treasury.Commands.RequestTransfer

  @org_id Ecto.UUID.generate()

  setup do
    # Create a source vault (EUR) to move funds from
    %Vault{
      id: "vault-eur-1",
      org_id: @org_id,
      name: "EUR Operating",
      bank_name: "Paystack",
      currency: "EUR",
      balance: Decimal.new(10_000_000),
      provider: "paystack",
      status: "active"
    }
    |> Repo.insert!()

    :ok
  end

  test "detects deficit and dispatches RequestTransfer from EUR vault to USD" do
    # 1. Forecast reports a deficit in USD
    event = %ForecastGenerated{
      org_id: @org_id,
      currency: "USD",
      horizon_days: 7,
      predictions: [%{amount: Decimal.new("-500000.00")}],
      generated_at: DateTime.utc_now()
    }

    # 2. Handle the event in the Saga
    commands = RebalanceManager.handle(%RebalanceManager{}, event)

    # 3. Verify the command
    assert [%RequestTransfer{} = cmd] = commands
    assert cmd.org_id == @org_id
    assert cmd.from_currency == "EUR"
    assert cmd.to_currency == "USD"
    assert Decimal.equal?(cmd.amount, 500000)
    assert cmd.user_id == "system-rebalance"
    assert cmd.recipient_data.vault_id == "vault-eur-1"
  end
end
