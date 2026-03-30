defmodule Nexus.Treasury.RebalanceOrchestrationTest do
  @moduledoc """
  BDD integration test for Strategic Portfolio Rebalancing.
  Verifies that ForecastGenerated events with deficits trigger automated
  RequestTransfer commands via the RebalanceManager saga.
  """
  use Cabbage.Feature, file: "treasury/rebalance_orchestration.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Repo
  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Treasury.Projections.Vault
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all("projection_versions")
      Repo.query!("TRUNCATE event_store.events CASCADE")
      Repo.delete_all(Vault)
    end)

    :ok
  end

  # --- Scenario: Generating a rebalance command from a deficit forecast ---

  defgiven ~r/^an organization has an active "(?<currency>[^"]+)" vault with "(?<amount>[^"]+)" balance$/,
           %{currency: currency, amount: amount},
           state do
    org_id = Nexus.Schema.generate_uuidv7()
    vault_id = Nexus.Schema.generate_uuidv7()

    Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.insert!(%Vault{
        id: vault_id,
        org_id: org_id,
        currency: currency,
        balance: Nexus.Schema.parse_decimal(amount),
        name: "Test Vault",
        bank_name: "Test Bank",
        provider: "manual",
        status: "active",
        updated_at: Nexus.Schema.utc_now()
      })
    end)

    {:ok, Map.merge(state, %{org_id: org_id, vault_id: vault_id, source_currency: currency})}
  end

  defwhen ~r/^a forecast reports a deficit of "(?<amount>[^"]+)" in "(?<currency>[^"]+)"$/,
          %{amount: amount, currency: currency},
          state do
    event = %ForecastGenerated{
      org_id: state.org_id,
      currency: currency,
      horizon_days: 7,
      predictions: [
        %{predicted_amount: "-" <> amount}
      ],
      generated_at: Nexus.Schema.utc_now()
    }

    # Dispatch via the saga's handle/2 directly for the orchestration test
    # to verify the command generation logic.
    commands = RebalanceManager.handle(%RebalanceManager{}, event)

    {:ok, Map.put(state, :dispatched_commands, List.wrap(commands))}
  end

  defthen ~r/^a transfer request from "(?<from>[^"]+)" to "(?<to>[^"]+)" should be dispatched for "(?<amount>[^"]+)"$/,
          %{from: from, to: to, amount: amount},
          state do
    command = Enum.find(state.dispatched_commands, fn
      %RequestTransfer{from_currency: ^from, to_currency: ^to} -> true
      _ -> false
    end)

    assert command != nil, "Expected RequestTransfer command from #{from} towards #{to} not found"
    assert Decimal.equal?(command.amount, Nexus.Schema.parse_decimal(amount))
    assert command.recipient_data.vault_id == state.vault_id

    {:ok, state}
  end

  defthen ~r/^the transfer should be attributed to "system-rebalance"$/, _vars, state do
    command = List.first(state.dispatched_commands)
    assert command.user_id == "system-rebalance"
    {:ok, state}
  end
end
