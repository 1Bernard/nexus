defmodule Nexus.Identity.Commands.VerifyBiometric do
  @moduledoc """
  Command representing a successful biometric verification.
  """
  @enforce_keys [:user_id, :org_id, :challenge_id, :verified_at]
  defstruct [:user_id, :org_id, :challenge_id, :verified_at]
end
