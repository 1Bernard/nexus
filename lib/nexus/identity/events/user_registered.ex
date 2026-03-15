defmodule Nexus.Identity.Events.UserRegistered do
  @moduledoc """
  Event emitted when a user has been successfully registered.
  """
  @derive Jason.Encoder
  @enforce_keys [:user_id, :org_id, :email, :role, :cose_key, :credential_id, :registered_at, :status]
  defstruct [
    :user_id,
    :org_id,
    :email,
    :role,
    :cose_key,
    :credential_id,
    :registered_at,
    :display_name,
    :status
  ]
end
