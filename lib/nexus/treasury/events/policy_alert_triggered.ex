defmodule Nexus.Treasury.Events.PolicyAlertTriggered do
  @moduledoc """
  Emitted when an exposure calculation exceeds the prescribed threshold.
  """
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at]
  defstruct [:policy_id, :org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at]
end
