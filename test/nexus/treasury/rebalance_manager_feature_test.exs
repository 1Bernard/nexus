defmodule Nexus.Treasury.RebalanceManagerFeatureTest do
  @moduledoc """
  Elite BDD tests for Treasury Rebalance Orchestration.
  """
  use Cabbage.Feature, file: "treasury/rebalance_orchestration.feature"
  use Nexus.DataCase

  alias Nexus.Treasury.ProcessManagers.RebalanceManager
  alias Nexus.Treasury.Events.ForecastGenerated
  alias Nexus.Treasury.Projections.Vault
  alias Nexus.Treasury.Commands.RequestTransfer

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(Vault)
    end)

    :ok
  end

  defgiven ~r/^an organization has an active "(?<currency>[^"]+)" vault with "(?<balance>[^"]+)" balance$/,
           %{currency: currency, balance: balance},
           _vars do
    org_id = Nexus.Schema.generate_uuidv7()
    vault_id = Nexus.Schema.generate_uuidv7()

    unboxed_run(fn ->
      %Vault{
        id: vault_id,
        org_id: org_id,
        name: "EUR Operating-#{:erlang.unique_integer([:positive])}",
        bank_name: "Nexus Bank",
        currency: currency,
        balance: Nexus.Schema.parse_decimal_safe(balance),
        provider: "nexus",
        status: "active"
      }
      |> Repo.insert!()
    end)

    {:ok, %{org_id: org_id, vault_id: vault_id}}
  end

  defwhen ~r/^a forecast reports a deficit of "(?<amount>[^"]+)" in "(?<currency>[^"]+)"$/,
          %{amount: amount_str, currency: currency},
          %{org_id: org_id} do
    amount = Nexus.Schema.parse_decimal_safe(amount_str)

    event = %ForecastGenerated{
      org_id: org_id,
      currency: currency,
      horizon_days: 7,
      # Negative amount in forecast means deficit
      predictions: [%{predicted_amount: Decimal.negate(amount)}],
      generated_at: DateTime.utc_now()
    }

    # Handle in Saga (requires DB access to find vaults)
    commands = unboxed_run(fn ->
      RebalanceManager.handle(%RebalanceManager{}, event)
    end)

    {:ok, %{commands: commands}}
  end

  defthen ~r/^a transfer request from "(?<from>[^"]+)" to "(?<to>[^"]+)" should be dispatched for "(?<amount>[^"]+)"$/,
          %{from: from, to: to, amount: amount_str},
          %{commands: commands, org_id: org_id} do
    amount = Nexus.Schema.parse_decimal_safe(amount_str)

    assert [%RequestTransfer{} = cmd] = commands
    assert cmd.org_id == org_id
    assert cmd.from_currency == from
    assert cmd.to_currency == to
    assert Decimal.equal?(cmd.amount, amount)

    :ok
  end

  defthen ~r/^the transfer should be attributed to "(?<user_id>[^"]+)"$/,
          %{user_id: user_id},
          %{commands: [cmd]} do
    assert cmd.user_id == user_id
    :ok
  end
end
