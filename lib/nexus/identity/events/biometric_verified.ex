defmodule Nexus.Identity.Events.BiometricVerified do
  @moduledoc """
  Immutable fact that a specific biometric key was used to verify identity.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          user_id: Types.binary_id(),
          org_id: Types.org_id(),
          handshake_id: Types.binary_id(),
          verified_at: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:user_id, :org_id, :handshake_id, :verified_at]
  defstruct [:user_id, :org_id, :handshake_id, :verified_at]
end
