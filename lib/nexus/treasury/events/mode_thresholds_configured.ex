defmodule Nexus.Treasury.Events.ModeThresholdsConfigured do
  @moduledoc """
  Event emitted when a system admin configures per-mode transfer thresholds for an organisation.
  """
  @derive [Jason.Encoder]
  @enforce_keys [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
end
