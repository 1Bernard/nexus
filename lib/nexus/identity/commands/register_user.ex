defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  Frictionless: only WebAuthn data needed. Role defaults to "trader".
  """
  @enforce_keys [:user_id, :org_id, :email, :attestation_object, :client_data_json]
  defstruct [
    :user_id,
    :org_id,
    :email,
    :attestation_object,
    :client_data_json,
    role: "trader",
    display_name: nil
  ]
end
