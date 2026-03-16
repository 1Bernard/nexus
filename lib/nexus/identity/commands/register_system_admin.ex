defmodule Nexus.Identity.Commands.RegisterSystemAdmin do
  @moduledoc """
  Specialized command to bootstrap the platform's root administrator.
  Bypasses physical WebAuthn attestation check but assigns a 'recovery' state.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          email: String.t(),
          display_name: String.t(),
          registered_at: Types.datetime()
        }
  @enforce_keys [:user_id, :org_id, :email, :display_name, :registered_at]
  defstruct [:user_id, :org_id, :email, :display_name, :registered_at]
end
