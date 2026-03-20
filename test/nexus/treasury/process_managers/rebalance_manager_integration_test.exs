defmodule Nexus.Treasury.ProcessManagers.RebalanceManagerIntegrationTest do
  use Nexus.DataCase
  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.Vault
  alias Nexus.Treasury.Commands.RequestTransfer

  setup do
    Repo.delete_all(Vault)
    org_id = Ecto.UUID.generate()
    vault_id = Nexus.Schema.generate_uuidv7()
    vault_name = "EUR Operating-#{:erlang.unique_integer([:positive])}"

    # Create a source vault (EUR) to move funds from
    %Vault{
      id: vault_id,
      org_id: org_id,
      name: vault_name,
      bank_name: "Paystack",
      currency: "EUR",
      balance: Decimal.new(10_000_000),
      provider: "paystack",
      status: "active"
    }
    |> Repo.insert!()

    {:ok, org_id: org_id, vault_id: vault_id}
  end

  test "detects deficit and dispatches RequestTransfer from EUR vault to USD", %{
    org_id: org_id,
    vault_id: vault_id
  } do
    # 1. Forecast reports a deficit in USD
    event = %ForecastGenerated{
      org_id: org_id,
      currency: "USD",
      horizon_days: 7,
      predictions: [%{amount: Decimal.new("-500000.00")}],
      generated_at: DateTime.utc_now()
    }

    # 2. Handle the event in the Saga
    commands = RebalanceManager.handle(%RebalanceManager{}, event)

    # 3. Verify the command
    assert [%RequestTransfer{} = cmd] = commands
    assert cmd.org_id == org_id
    assert cmd.from_currency == "EUR"
    assert cmd.to_currency == "USD"
    assert Decimal.equal?(cmd.amount, 500_000)
    assert cmd.user_id == "system-rebalance"
    assert cmd.recipient_data.vault_id == vault_id
  end
end
