defmodule Nexus.Treasury.Aggregates.Vault do
  @moduledoc """
  Aggregate to manage physical bank accounts (Vaults) and their balances.
  """
  @derive Jason.Encoder
  defstruct [
    :id,
    :org_id,
    :currency,
    :balance,
    :status,
    :daily_withdrawal_limit,
    :requires_multi_sig
  ]

  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Commands.{RegisterVault, SyncVaultBalance, DebitVault, CreditVault}
  alias Nexus.Treasury.Events.{VaultRegistered, VaultBalanceSynced, VaultDebited, VaultCredited}

  # --- Command Handlers ---

  @spec execute(t(), RegisterVault.t() | SyncVaultBalance.t() | DebitVault.t() | CreditVault.t()) ::
          Commanded.Aggregate.Multi.t() | [struct()] | struct() | {:error, atom()}
  def execute(%__MODULE__{id: nil}, %RegisterVault{} = cmd) do
    %VaultRegistered{
      vault_id: cmd.vault_id,
      org_id: cmd.org_id,
      name: cmd.name,
      bank_name: cmd.bank_name,
      account_number: cmd.account_number,
      iban: cmd.iban,
      currency: cmd.currency,
      provider: cmd.provider,
      registered_at: cmd.registered_at,
      daily_withdrawal_limit: cmd.daily_withdrawal_limit,
      requires_multi_sig: cmd.requires_multi_sig
    }
  end

  # Idempotency: If already registered, do nothing
  def execute(%__MODULE__{}, %RegisterVault{}), do: []

  def execute(%__MODULE__{id: id}, %SyncVaultBalance{} = cmd) when not is_nil(id) do
    %VaultBalanceSynced{
      vault_id: cmd.vault_id,
      org_id: cmd.org_id,
      amount: cmd.amount,
      currency: cmd.currency,
      synced_at: cmd.synced_at
    }
  end

  def execute(%__MODULE__{id: id}, %DebitVault{} = cmd) when not is_nil(id) do
    %VaultDebited{
      vault_id: cmd.vault_id,
      org_id: cmd.org_id,
      amount: cmd.amount,
      currency: cmd.currency,
      transfer_id: cmd.transfer_id,
      debited_at: cmd.debited_at
    }
  end

  def execute(%__MODULE__{id: id}, %CreditVault{} = cmd) when not is_nil(id) do
    %VaultCredited{
      vault_id: cmd.vault_id,
      org_id: cmd.org_id,
      amount: cmd.amount,
      currency: cmd.currency,
      transfer_id: cmd.transfer_id,
      credited_at: cmd.credited_at
    }
  end

  # --- State Transitions ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = state, %VaultRegistered{} = event) do
    %__MODULE__{
      state
      | id: event.vault_id,
        org_id: event.org_id,
        currency: event.currency,
        balance: Decimal.new(0),
        status: :active,
        daily_withdrawal_limit: event.daily_withdrawal_limit,
        requires_multi_sig: event.requires_multi_sig
    }
  end

  def apply(%__MODULE__{} = state, %VaultBalanceSynced{} = event) do
    %__MODULE__{state | balance: event.amount}
  end

  def apply(%__MODULE__{balance: balance} = state, %VaultDebited{} = event) do
    %__MODULE__{state | balance: Decimal.sub(balance, event.amount)}
  end

  def apply(%__MODULE__{balance: balance} = state, %VaultCredited{} = event) do
    %__MODULE__{state | balance: Decimal.add(balance, event.amount)}
  end
end
