defmodule Nexus.Treasury.Commands.CreditVault do
  @moduledoc """
  Command to credit a Vault (inflow).
  """
  alias Nexus.Types

  defstruct [:vault_id, :org_id, :amount, :currency, :transfer_id, :credited_at]

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          transfer_id: Types.binary_id() | nil,
          credited_at: Types.datetime()
        }
end
