defmodule Nexus.Identity.Events.UserRegistered do
  @moduledoc """
  Event emitted when a user has been successfully registered.
  """
  @derive Jason.Encoder
  @enforce_keys [:user_id, :email, :role, :cose_key, :credential_id, :registered_at]
  defstruct [:user_id, :email, :role, :cose_key, :credential_id, :registered_at]
end
