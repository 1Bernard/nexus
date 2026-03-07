defmodule Nexus.Identity.Events.StepUpVerified do
  @moduledoc """
  Event emitted when a secondary biometric verification succeeds.
  """
  @derive [Jason.Encoder]
  @enforce_keys [:user_id, :org_id, :action_id, :verified_at]
  defstruct [:user_id, :org_id, :action_id, :verified_at]
end
