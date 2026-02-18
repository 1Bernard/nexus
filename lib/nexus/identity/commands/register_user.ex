defmodule Nexus.Identity.Commands.RegisterUser do
  @moduledoc """
  Command to register a new user in the system.
  """
  @enforce_keys [:user_id, :email, :role, :public_key]
  defstruct [:user_id, :email, :role, :public_key]
end
