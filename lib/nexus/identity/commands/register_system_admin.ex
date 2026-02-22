defmodule Nexus.Identity.Commands.RegisterSystemAdmin do
  @moduledoc """
  Specialized command to bootstrap the platform's root administrator.
  Bypasses physical WebAuthn attestation check but assigns a 'recovery' state.
  """
  @enforce_keys [:user_id, :org_id, :email, :display_name]
  defstruct [:user_id, :org_id, :email, :display_name]
end
