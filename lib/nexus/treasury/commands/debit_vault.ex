defmodule Nexus.Treasury.Commands.DebitVault do
  @moduledoc """
  Command to debit a Vault (outflow).
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          transfer_id: Types.binary_id() | nil,
          debited_at: Types.datetime()
        }

  @enforce_keys [:vault_id, :org_id, :amount, :currency, :debited_at]
  defstruct [:vault_id, :org_id, :amount, :currency, :transfer_id, :debited_at]
end
