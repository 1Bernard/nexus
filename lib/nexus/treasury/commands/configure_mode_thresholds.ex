defmodule Nexus.Treasury.Commands.ConfigureModeThresholds do
  @moduledoc """
  Command to configure the baseline thresholds for standard, strict, and relaxed modes.
  """
  @enforce_keys [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
end
