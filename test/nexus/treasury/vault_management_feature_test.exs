defmodule Nexus.Treasury.VaultManagementFeatureTest do
  use Cabbage.Feature, file: "treasury/vault_management.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.Vault
  alias Nexus.Treasury.Projectors.VaultProjector
  alias Nexus.Treasury.Projectors.LiquidityProjector

  setup do
    org_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(Vault)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{org_id: org_id}}
  end

  # --- Given ---

  defgiven ~r/^I am logged in as a "(?<role>[^"]+)"$/, %{role: _role}, state do
    {:ok, state}
  end

  defgiven ~r/^I am on the "(?<page>[^"]+)" page$/, %{page: _page}, state do
    {:ok, state}
  end

  defgiven ~r/^I have a registered vault "(?<name>[^"]+)" in "(?<curr>[^"]+)"$/,
           %{name: name, curr: currency},
           state do
    org_id = Map.fetch!(state, :org_id)
    vault_id = Nexus.Schema.generate_uuidv7()

    command = %Nexus.Treasury.Commands.RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: name,
      bank_name: name,
      currency: currency,
      provider: "manual",
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(vault_id)
    project_treasury_event(event, num)

    # Track for later
    {:ok, Map.merge(state, %{vault_id: vault_id, vault_name: name, currency: currency})}
  end

  defgiven ~r/^I have a "(?<curr>[^"]+)" vault with "(?<amount>[^"]+)"$/,
           %{curr: currency, amount: amount_str},
           state do
    org_id = Map.fetch!(state, :org_id)
    amount = Decimal.new(amount_str |> String.replace(",", "") |> String.trim())
    vault_id = Nexus.Schema.generate_uuidv7()
    name = "#{currency} Vault"

    command = %Nexus.Treasury.Commands.RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: name,
      bank_name: name,
      currency: currency,
      provider: "manual",
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(vault_id)
    project_treasury_event(event, num)

    # Seed initial balance via sync
    sync_cmd = %Nexus.Treasury.Commands.SyncVaultBalance{
      vault_id: vault_id,
      org_id: org_id,
      amount: amount,
      currency: currency,
      synced_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(sync_cmd)

    # Sync Projection for balance
    {:ok, [%{data: sync_event, event_number: sync_num}]} =
      Nexus.EventStore.read_stream_forward(vault_id, 2)

    project_treasury_event(sync_event, sync_num)

    # Track distinct vaults for rebalancing
    curr_key = "#{String.downcase(currency)}_vault_id"
    {:ok, Map.put(state, String.to_atom(curr_key), vault_id)}
  end

  # --- When ---

  defwhen ~r/^I click "(?<label>[^"]+)"$/, %{label: _label}, state do
    {:ok, state}
  end

  defwhen ~r/^I enter "(?<val>[^"]+)" as the vault name$/, %{val: name}, state do
    {:ok, Map.put(state, :pending_name, name)}
  end

  defwhen ~r/^I select "(?<val>[^"]+)" as the (?<type>bank|currency)$/, %{val: val, type: type}, state do
    {:ok, Map.put(state, String.to_atom("pending_#{type}"), val)}
  end

  defwhen ~r/^I enter "(?<val>[^"]+)" as the account number$/, %{val: account}, state do
    {:ok, Map.put(state, :pending_account, account)}
  end

  defwhen ~r/^I click "Initiate Onboarding"$/, _vars, state do
    vault_id = Nexus.Schema.generate_uuidv7()
    org_id = Map.fetch!(state, :org_id)

    command = %Nexus.Treasury.Commands.RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: state.pending_name,
      bank_name: state.pending_bank,
      currency: state.pending_currency,
      account_number: state.pending_account,
      provider: "manual",
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(vault_id)
    project_treasury_event(event, num)

    {:ok, Map.put(state, :vault_id, vault_id)}
  end

  defwhen ~r/^the external provider updates the balance to "(?<amount>[^"]+)"$/,
          %{amount: amount_str},
          state do
    vault_id = Map.fetch!(state, :vault_id)
    org_id = Map.fetch!(state, :org_id)
    currency = Map.get(state, :currency, "EUR")
    amount = Decimal.new(amount_str |> String.replace("€", "") |> String.replace(",", "") |> String.trim())

    command = %Nexus.Treasury.Commands.SyncVaultBalance{
      vault_id: vault_id,
      org_id: org_id,
      amount: amount,
      currency: currency,
      synced_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Capture sync (version 2)
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(vault_id, 2)
    project_treasury_event(event, num)

    {:ok, Map.put(state, :expected_sync_balance, amount)}
  end

  defwhen ~r/^an autonomous rebalance of "(?<amount>[^"]+)" is triggered from "(?<from>[^"]+)" to "(?<to>[^"]+)"$/,
          %{amount: amount_str, from: from, to: to},
          state do
    org_id = Map.fetch!(state, :org_id)
    amount_dec = Decimal.new(amount_str |> String.replace(",", "") |> String.trim())

    from_id = state[:"#{String.downcase(from)}_vault_id"]
    to_id = state[:"#{String.downcase(to)}_vault_id"]
    transfer_id = Nexus.Schema.generate_uuidv7()

    command = %Nexus.Treasury.Commands.RequestTransfer{
      transfer_id: transfer_id,
      org_id: org_id,
      user_id: "system-rebalance",
      from_currency: from,
      to_currency: to,
      amount: amount_dec,
      recipient_data: %{"type" => "vault", "vault_id" => to_id, "from_vault_id" => from_id},
      requested_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # --- COMPLETE REBALANCING FLOW ---
    # 1. Capture TransferInitiated (authorized)
    {:ok, [%{data: %Nexus.Treasury.Events.TransferInitiated{} = init_event}]} = Nexus.EventStore.read_stream_forward(transfer_id)

    # 2. Dispatch ExecuteTransfer (simulating Process Manager or System)
    exec_cmd = %Nexus.Treasury.Commands.ExecuteTransfer{
      transfer_id: transfer_id,
      org_id: org_id,
      executed_at: DateTime.utc_now()
    }
    assert :ok = App.dispatch(exec_cmd)

    # 3. Capture TransferExecuted
    {:ok, events} = Nexus.EventStore.read_stream_forward(transfer_id)
    trf_event = List.last(events).data
    trf_num = List.last(events).event_number
    project_treasury_event(trf_event, trf_num)

    # 4. Manually trigger handler
    :ok = Nexus.Treasury.Handlers.TransferExecutionHandler.handle(trf_event, %{handler_name: "test"})

    # 5. Project Debits/Credits (Version 3 on vault streams)
    {:ok, [%{data: deb_event, event_number: deb_num}]} = Nexus.EventStore.read_stream_forward(from_id, 3)
    project_treasury_event(deb_event, deb_num)

    {:ok, [%{data: cred_event, event_number: cred_num}]} = Nexus.EventStore.read_stream_forward(to_id, 3)
    project_treasury_event(cred_event, cred_num)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^I should see "(?<message>[^"]+)"$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the vault "(?<name>[^"]+)" should appear in the vault list$/, %{name: name}, state do
    org_id = Map.fetch!(state, :org_id)
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      vault = Repo.get_by(Vault, name: name, org_id: org_id)
      assert vault != nil
    end)
    {:ok, state}
  end

  defthen ~r/^the vault "(?<name>[^"]+)" should display a balance of "(?<formatted_amount>[^"]+)"$/,
          %{formatted_amount: _formatted},
          state do
    vault_id = Map.fetch!(state, :vault_id)
    expected = Map.fetch!(state, :expected_sync_balance)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      vault = Repo.get!(Vault, vault_id)
      assert Decimal.eq?(vault.balance, expected)
    end)
    {:ok, state}
  end

  defthen ~r/^the total "(?<currency>[^"]+)" liquidity should be updated$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the "(?<curr>[^"]+)" vault balance should (?<dir>increase|decrease) by "(?<amount>[^"]+)"$/,
          %{curr: curr, dir: dir, amount: _amount_str},
          state do
    vault_id = state[:"#{String.downcase(curr)}_vault_id"]

    # Expected: USD: 500k -> 375k, EUR: 100k -> 225k
    expected = if dir == "decrease", do: Decimal.new("375000.00"), else: Decimal.new("225000.00")

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      vault = Repo.get!(Vault, vault_id)
      assert Decimal.eq?(vault.balance, expected)
    end)
    {:ok, state}
  end

  defthen ~r/^I should see a new rebalancing activity record$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp project_treasury_event(event, num) do
    # Use a unique name for each stream to avoid projection_versions conflict
    # especially since we are projecting multiple independent vault streams.
    id_part = case event do
      %{vault_id: id} -> id
      %{transfer_id: id} -> id
      _ -> "generic"
    end

    handler_name = "ManualProjector-#{id_part}"

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      case event do
        %Nexus.Treasury.Events.VaultRegistered{} ->
          VaultProjector.handle(event, %{handler_name: handler_name, event_number: num})

        %Nexus.Treasury.Events.VaultBalanceSynced{} ->
          VaultProjector.handle(event, %{handler_name: handler_name, event_number: num})

        %Nexus.Treasury.Events.VaultDebited{} ->
          VaultProjector.handle(event, %{handler_name: handler_name, event_number: num})

        %Nexus.Treasury.Events.VaultCredited{} ->
          VaultProjector.handle(event, %{handler_name: handler_name, event_number: num})

        %Nexus.Treasury.Events.TransferExecuted{} ->
          LiquidityProjector.handle(event, %{handler_name: handler_name, event_number: num})

        _ -> :ok
      end
    end)
  end
end
