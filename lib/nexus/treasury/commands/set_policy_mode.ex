defmodule Nexus.Treasury.Commands.SetPolicyMode do
  @moduledoc """
  Command to set the named risk tolerance mode for an organisation's treasury policy.
  Valid modes are: "standard", "strict", "relaxed".
  The threshold is derived from the mode and included for aggregate validation.
  """
  @enforce_keys [:policy_id, :org_id, :mode, :threshold, :actor_email]
  defstruct [:policy_id, :org_id, :mode, :threshold, :actor_email]
end
