defmodule Nexus.Treasury.Events.VaultBalanceSynced do
  @moduledoc """
  Emitted when a Vault's balance is synchronized.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          synced_at: Types.datetime()
        }

  defstruct [:vault_id, :org_id, :amount, :currency, :synced_at]
end
