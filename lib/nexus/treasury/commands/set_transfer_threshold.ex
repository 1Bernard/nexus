defmodule Nexus.Treasury.Commands.SetTransferThreshold do
  @moduledoc """
  Command to update the biometric step-up threshold for an organization.
  """
  @enforce_keys [:policy_id, :org_id, :threshold, :set_at]
  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
