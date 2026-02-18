defmodule Nexus.Identity.Commands.VerifyBiometric do
  @moduledoc """
  Command representing the intent to authorize via hardware biometric.
  """
  @enforce_keys [:user_id, :challenge_id, :signature]
  defstruct [:user_id, :challenge_id, :signature]
end
