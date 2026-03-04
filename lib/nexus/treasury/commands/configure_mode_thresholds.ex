defmodule Nexus.Treasury.Commands.ConfigureModeThresholds do
  @moduledoc """
  Command to configure the baseline thresholds for standard, strict, and relaxed modes.
  """
  @enforce_keys [:policy_id, :org_id, :mode_thresholds, :actor_email]
  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email]
end
