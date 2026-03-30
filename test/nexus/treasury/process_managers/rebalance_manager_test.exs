defmodule Nexus.Treasury.ProcessManagers.RebalanceManagerTest do
  @moduledoc """
  Elite BDD tests for Auto Rebalance Trigger.
  """
  use Cabbage.Feature, async: false, file: "treasury/auto_rebalance_trigger.feature"
  use Nexus.DataCase

  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.{ForecastGenerated, TransferInitiated}
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Treasury.Projections.Vault
  alias Nexus.Repo

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(Vault)
    end)
    :ok
  end

  # --- Given ---

  defgiven ~r/^a vault "(?<name>[^"]+)" with balance "(?<balance>[^"]+)" exists$/,
           %{name: name, balance: balance},
           _state do
    org_id = Nexus.Schema.generate_uuidv7()
    vault_id = Nexus.Schema.generate_uuidv7()

    unboxed_run(fn ->
      Repo.insert!(%Vault{
        id: vault_id,
        org_id: org_id,
        name: name,
        bank_name: "Test Bank",
        currency: "EUR",
        balance: Decimal.new(balance),
        provider: "manual"
      })
    end)

    {:ok, %{org_id: org_id, vault_id: vault_id}}
  end

  defgiven ~r/^an active rebalance saga for "(?<currency>[^"]+)"$/, %{currency: currency}, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id, currency: currency, saga: %RebalanceManager{org_id: org_id, target_currency: currency}}}
  end

  # --- When ---

  defwhen ~r/^a forecast for "(?<currency>[^"]+)" predicts a deficit of "(?<amount>[^"]+)"$/,
          %{currency: currency, amount: amount},
          %{org_id: org_id} do
    event = %ForecastGenerated{
      org_id: org_id,
      currency: currency,
      horizon_days: 7,
      predictions: [%{predicted_amount: Decimal.negate(Decimal.new(amount))}],
      generated_at: DateTime.utc_now()
    }

    commands = RebalanceManager.handle(%RebalanceManager{}, event)
    {:ok, %{commands: commands}}
  end

  defwhen ~r/^a forecast for "(?<currency>[^"]+)" predicts a surplus of "(?<amount>[^"]+)"$/,
          %{currency: currency, amount: amount},
          %{org_id: org_id} do
    event = %ForecastGenerated{
      org_id: org_id,
      currency: currency,
      horizon_days: 7,
      predictions: [%{predicted_amount: Decimal.new(amount)}],
      generated_at: DateTime.utc_now()
    }

    commands = RebalanceManager.handle(%RebalanceManager{}, event)
    {:ok, %{commands: commands}}
  end

  defwhen ~r/^a transfer of "(?<amount>[^"]+)" from "(?<from>[^"]+)" to "(?<to>[^"]+)" is initiated$/,
          %{amount: amount, from: from, to: to},
          %{org_id: org_id, saga: saga} do
    event = %TransferInitiated{
      transfer_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      user_id: Nexus.Schema.generate_uuidv7(),
      from_currency: from,
      to_currency: to,
      amount: amount,
      status: "pending_authorization",
      requested_at: DateTime.utc_now()
    }

    new_saga = RebalanceManager.apply(saga, event)
    {:ok, %{saga: new_saga}}
  end

  # --- Then ---

  defthen ~r/^a Rebalance command should be dispatched for "(?<currency>[^"]+)"$/,
          %{currency: currency},
          %{commands: [command]} do
    assert %RequestTransfer{} = command
    assert command.to_currency == currency
    assert command.from_currency == "EUR"
    :ok
  end

  defthen "no Rebalance command should be dispatched", _args, %{commands: commands} do
    assert commands == []
    :ok
  end

  defthen "the rebalance saga should be marked as completed", _args, %{saga: saga} do
    assert saga.completed == true
    :ok
  end
end
