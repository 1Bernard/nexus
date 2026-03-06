defmodule Nexus.Identity.Commands.VerifyStepUp do
  @moduledoc """
  Command representing a successful step-up biometric verification.
  """
  @enforce_keys [:user_id, :org_id, :challenge_id, :action_id, :verified_at]
  defstruct [:user_id, :org_id, :challenge_id, :action_id, :verified_at]
end
