defmodule Nexus.Treasury.VaultManagementFeatureTest do
  use Cabbage.Feature, file: "treasury/vault_management.feature"
  use Nexus.DataCase
  @moduletag :feature

  alias Nexus.App
  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Treasury.Projections.Vault

  setup do
    # We avoid TRUNCATE here as it causes deadlocks/timeouts with many projectors.
    # Instead, we rely on unique IDs and resilient projections.
    start_supervised!(Nexus.Identity.Projectors.UserRegistrationProjector)
    start_supervised!(Nexus.Identity.Projectors.UserProjector)
    start_supervised!(Nexus.Treasury.Projectors.VaultProjector)
    start_supervised!(Nexus.Treasury.Projectors.TransferProjector)
    start_supervised!(Nexus.Treasury.Handlers.TransferExecutionHandler)
    start_supervised!(Nexus.Treasury.ProcessManagers.TransferManager)

    # Clean only the projections for this test run
    Nexus.Repo.delete_all(Nexus.Identity.Projections.User)
    Nexus.Repo.delete_all(Nexus.Treasury.Projections.Vault)
    Nexus.Repo.delete_all(Nexus.Treasury.Projections.Transfer)
    Nexus.Repo.delete_all("projection_versions")

    :ok
  end

  # --- Given ---

  defgiven ~r/^I am logged in as a "(?<role>[^"]+)"$/, %{role: role}, state do
    user_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: "treasurer-#{Ecto.UUID.generate()}@nexus.financial",
      display_name: "Test Treasurer",
      role: role,
      cose_key: Base.encode64("mock"),
      credential_id: Base.encode64("mock"),
      registered_at: DateTime.utc_now()
    }

    :ok = App.dispatch(command)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id})}
  end

  defgiven ~r/^I am on the "(?<page>[^"]+)" page$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^I have a registered vault "(?<name>[^"]+)" in "(?<currency>[^"]+)"$/,
           %{name: name, currency: currency},
           state do
    org_id = Map.fetch!(state, :org_id)

    :ok =
      Nexus.Treasury.register_vault(%{
        org_id: org_id,
        name: name,
        bank_name: "Test Bank",
        currency: currency,
        provider: "mock"
      })

    # Poll for projection
    vault = wait_for_vault_by_name(name, org_id)

    {:ok, Map.put(state, :vault_id, vault.id)}
  end

  defgiven ~r/^I have a "(?<currency>[^"]+)" vault with "(?<amount>[^"]+)"$/,
           %{currency: currency, amount: amount},
           state do
    org_id = Map.fetch!(state, :org_id)
    vault_name = "#{currency} Vault - #{Ecto.UUID.generate()}"

    :ok =
      Nexus.Treasury.register_vault(%{
        org_id: org_id,
        name: vault_name,
        bank_name: "Test Bank",
        currency: currency,
        provider: "mock"
      })

    vault = wait_for_vault_by_name(vault_name, org_id)

    amount_dec = Decimal.new(String.replace(amount, ",", ""))

    :ok =
      Nexus.Treasury.sync_vault_balance(%{
        vault_id: vault.id,
        org_id: org_id,
        amount: amount_dec,
        currency: currency
      })

    # Wait for balance sync projection
    wait_for_balance(vault.id, amount_dec)

    {:ok, Map.put(state, :"#{String.downcase(currency)}_vault_id", vault.id)}
  end

  # --- When ---

  defwhen ~r/^I click "(?<button>[^"]+)"$/, _vars, state do
    {:ok, state}
  end

  defwhen ~r/^I enter "(?<value>[^"]+)" as the vault name$/, %{value: value}, state do
    # Add uniqueness to avoid collisions if we are not truncating
    unique_name = "#{value} - #{Ecto.UUID.generate()}"
    {:ok, Map.put(state, :reg_name, unique_name)}
  end

  defwhen ~r/^I select "(?<value>[^"]+)" as the bank$/, %{value: value}, state do
    {:ok, Map.put(state, :reg_bank, value)}
  end

  defwhen ~r/^I select "(?<value>[^"]+)" as the currency$/, %{value: value}, state do
    {:ok, Map.put(state, :reg_currency, value)}
  end

  defwhen ~r/^I enter "(?<value>[^"]+)" as the account number$/, %{value: value}, state do
    {:ok, Map.put(state, :reg_account, value)}
  end

  defwhen ~r/^I click "Initiate Onboarding"$/, _vars, state do
    org_id = Map.fetch!(state, :org_id)

    :ok =
      Nexus.Treasury.register_vault(%{
        org_id: org_id,
        name: state.reg_name,
        bank_name: state.reg_bank,
        currency: state.reg_currency,
        provider: "mock",
        account_number: state.reg_account
      })

    {:ok, state}
  end

  defwhen ~r/^the external provider updates the balance to "(?<amount>[^"]+)"$/,
          %{amount: amount},
          state do
    amount_dec = Decimal.new(String.replace(amount, ",", ""))
    org_id = Map.fetch!(state, :org_id)
    vault_id = Map.fetch!(state, :vault_id)
    vault = Nexus.Repo.get!(Vault, vault_id)

    :ok =
      Nexus.Treasury.sync_vault_balance(%{
        vault_id: vault_id,
        org_id: org_id,
        amount: amount_dec,
        currency: vault.currency
      })

    {:ok, Map.put(state, :expected_sync_balance, amount_dec)}
  end

  defwhen ~r/^an autonomous rebalance of "(?<amount>[^"]+)" is triggered from "(?<from>[^"]+)" to "(?<to>[^"]+)"$/,
          %{amount: amount, from: from, to: to},
          state do
    amount_dec = Decimal.new(String.replace(amount, ",", ""))
    org_id = Map.fetch!(state, :org_id)
    from_vault = Nexus.Repo.get!(Vault, state[:"#{String.downcase(from)}_vault_id"])
    to_vault = Nexus.Repo.get!(Vault, state[:"#{String.downcase(to)}_vault_id"])

    command = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: Ecto.UUID.generate(),
      org_id: org_id,
      user_id: "system-rebalance",
      from_currency: from,
      to_currency: to,
      amount: amount_dec,
      recipient_data: %{
        type: "vault",
        vault_id: to_vault.id,
        from_vault_id: from_vault.id
      },
      requested_at: DateTime.utc_now()
    }

    :ok = App.dispatch(command)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^I should see "(?<message>[^"]+)"$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the vault "(?<name>[^"]+)" should appear in the vault list$/,
          %{name: _name},
          state do
    org_id = Map.fetch!(state, :org_id)
    # Check for the unique name we generated
    vault = wait_for_vault_by_name(state.reg_name, org_id)
    assert vault, "Vault should be projected"
    {:ok, state}
  end

  defthen ~r/^the vault "(?<name>[^"]+)" should display a balance of "(?<formatted_amount>[^"]+)"$/,
          %{name: _name},
          state do
    vault_id = Map.fetch!(state, :vault_id)
    expected = Map.fetch!(state, :expected_sync_balance)

    vault = wait_for_balance(vault_id, expected)
    assert Decimal.eq?(vault.balance, expected)
    {:ok, state}
  end

  defthen ~r/^the total "(?<currency>[^"]+)" liquidity should be updated$/,
          %{currency: _currency},
          state do
    {:ok, state}
  end

  defthen ~r/^the "(?<currency>[^"]+)" vault balance should (?<direction>increase|decrease) by "(?<amount>[^"]+)"$/,
          %{currency: currency, direction: direction, amount: amount},
          state do
    vault_id = state[:"#{String.downcase(currency)}_vault_id"]
    amount_dec = Decimal.new(String.replace(amount, ",", ""))

    # We use polling to wait for rebalance completion
    initial_balance =
      if direction == "increase", do: Decimal.new("100000.00"), else: Decimal.new("500000.00")

    expected_balance =
      if direction == "increase" do
        Decimal.add(initial_balance, amount_dec)
      else
        Decimal.sub(initial_balance, amount_dec)
      end

    vault = wait_for_balance(vault_id, expected_balance)

    assert Decimal.eq?(vault.balance, expected_balance)
    {:ok, state}
  end

  defthen ~r/^I should see a new rebalancing activity record$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp wait_for_vault_by_name(name, org_id, retries \\ 20) do
    case Nexus.Repo.get_by(Vault, name: name, org_id: org_id) do
      nil when retries > 0 ->
        Process.sleep(200)
        wait_for_vault_by_name(name, org_id, retries - 1)

      vault ->
        vault
    end
  end

  defp wait_for_balance(vault_id, expected_balance, retries \\ 30) do
    vault = Nexus.Repo.get!(Vault, vault_id)

    if Decimal.eq?(vault.balance, expected_balance) or retries == 0 do
      vault
    else
      Process.sleep(200)
      wait_for_balance(vault_id, expected_balance, retries - 1)
    end
  end
end
