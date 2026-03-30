defmodule Nexus.Treasury.Aggregates.VaultTest do
  use ExUnit.Case, async: true
  alias Nexus.Treasury.Aggregates.Vault
  alias Nexus.Treasury.Commands.{RegisterVault, SyncVaultBalance, DebitVault, CreditVault}
  alias Nexus.Treasury.Events.{VaultRegistered, VaultBalanceSynced, VaultDebited, VaultCredited}

  describe "RegisterVault" do
    test "emits VaultRegistered event" do
      vault_id = Nexus.Schema.generate_uuidv7()
      cmd = %RegisterVault{
        vault_id: vault_id,
        org_id: Nexus.Schema.generate_uuidv7(),
        name: "Main USD",
        bank_name: "Paystack",
        currency: "USD",
        provider: "paystack",
        registered_at: DateTime.utc_now()
      }

      assert %VaultRegistered{vault_id: ^vault_id, currency: "USD"} =
               Vault.execute(%Vault{id: nil}, cmd)
    end
  end

  describe "SyncVaultBalance" do
    test "updates balance" do
      vault_id = Nexus.Schema.generate_uuidv7()
      org_id = Nexus.Schema.generate_uuidv7()
      state = %Vault{id: vault_id, balance: Decimal.new(0)}

      cmd = %SyncVaultBalance{
        vault_id: vault_id,
        org_id: org_id,
        amount: Decimal.new(500),
        currency: "USD",
        synced_at: DateTime.utc_now()
      }

      assert %VaultBalanceSynced{amount: amount} = Vault.execute(state, cmd)
      assert Decimal.equal?(amount, 500)
    end
  end

  describe "DebitVault" do
    test "decreases balance" do
      vault_id = Nexus.Schema.generate_uuidv7()
      state = %Vault{id: vault_id, balance: Decimal.new(1000)}
      event = %VaultDebited{vault_id: vault_id, amount: Decimal.new(200)}

      new_state = Vault.apply(state, event)
      assert Decimal.equal?(new_state.balance, 800)
    end
  end

  describe "CreditVault" do
    test "increases balance" do
      vault_id = Nexus.Schema.generate_uuidv7()
      state = %Vault{id: vault_id, balance: Decimal.new(1000)}
      event = %VaultCredited{vault_id: vault_id, amount: Decimal.new(200)}

      new_state = Vault.apply(state, event)
      assert Decimal.equal?(new_state.balance, 1200)
    end
  end
end
