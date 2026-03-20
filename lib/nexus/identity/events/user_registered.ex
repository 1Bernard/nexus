defmodule Nexus.Identity.Events.UserRegistered do
  @moduledoc """
  Event emitted when a user has been successfully registered.
  """
  alias Nexus.Types

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          email: String.t(),
          role: String.t(),
          cose_key: binary(),
          credential_id: Types.binary_id(),
          registered_at: Types.datetime(),
          display_name: String.t() | nil,
          status: String.t()
        }

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
