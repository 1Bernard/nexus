defmodule Nexus.Treasury.Commands.SyncVaultBalance do
  @moduledoc """
  Command to synchronize the balance of a Vault from an external source.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          synced_at: Types.datetime()
        }

  @enforce_keys [:vault_id, :org_id, :amount, :currency, :synced_at]
  defstruct [:vault_id, :org_id, :amount, :currency, :synced_at]
end
