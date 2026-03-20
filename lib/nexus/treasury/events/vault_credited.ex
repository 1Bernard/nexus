defmodule Nexus.Treasury.Events.VaultCredited do
  @moduledoc """
  Emitted when a Vault is credited.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          amount: Types.money(),
          currency: Types.currency(),
          transfer_id: Types.binary_id() | nil,
          credited_at: Types.datetime()
        }

  defstruct [:vault_id, :org_id, :amount, :currency, :transfer_id, :credited_at]
end
