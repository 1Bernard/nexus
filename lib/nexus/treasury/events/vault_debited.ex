defmodule Nexus.Treasury.Events.VaultDebited do
  @moduledoc """
  Emitted when a Vault is debited.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [:vault_id, :org_id, :amount, :currency, :transfer_id, :debited_at]

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          transfer_id: Types.binary_id() | nil,
          debited_at: Types.datetime()
        }
end
