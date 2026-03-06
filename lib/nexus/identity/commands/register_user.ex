defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  Expects pre-verified WebAuthn keys.
  """
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
