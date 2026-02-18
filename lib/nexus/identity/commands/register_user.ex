defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  """
  @enforce_keys [:user_id, :email, :role, :attestation_object, :client_data_json]
  defstruct [:user_id, :email, :role, :attestation_object, :client_data_json]
end
