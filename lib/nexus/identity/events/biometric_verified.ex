defmodule Nexus.Identity.Events.BiometricVerified do
  @moduledoc """
  Immutable fact that a specific biometric key was used to verify identity.
  """
  @derive Jason.Encoder
  @enforce_keys [:user_id, :handshake_id, :verified_at]
  defstruct [:user_id, :handshake_id, :verified_at]
end
