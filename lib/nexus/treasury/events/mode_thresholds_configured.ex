defmodule Nexus.Treasury.Events.ModeThresholdsConfigured do
  @derive [Jason.Encoder]
  @enforce_keys [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
  defstruct [:policy_id, :org_id, :mode_thresholds, :actor_email, :configured_at]
end
