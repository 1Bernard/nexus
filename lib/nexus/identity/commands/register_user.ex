defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  Expects pre-verified WebAuthn keys.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          email: String.t(),
          cose_key: String.t(),
          credential_id: Types.credential_id(),
          role: String.t(),
          display_name: String.t() | nil,
          registered_at: DateTime.t() | nil
        }

  @enforce_keys [:user_id, :org_id, :email, :cose_key, :credential_id, :registered_at]
  defstruct [
    :user_id,
    :org_id,
    :email,
    :cose_key,
    :credential_id,
    role: "trader",
    display_name: nil,
    registered_at: nil
  ]
end
