defmodule Nexus.Treasury.Events.VaultRegistered do
  @moduledoc """
  Emitted when a new Vault is registered.
  """
  alias Nexus.Types

  @derive Jason.Encoder
  defstruct [
    :vault_id,
    :org_id,
    :name,
    :bank_name,
    :account_number,
    :iban,
    :currency,
    :provider,
    :registered_at
  ]

  @type t :: %__MODULE__{
          vault_id: Types.vault_id(),
          org_id: Types.org_id(),
          name: String.t(),
          bank_name: String.t(),
          account_number: String.t() | nil,
          iban: String.t() | nil,
          currency: Types.currency(),
          provider: String.t(),
          registered_at: Types.datetime()
        }
end
