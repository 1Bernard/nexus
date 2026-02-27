defmodule Nexus.Treasury.Events.PolicyModeChanged do
  @moduledoc """
  Emitted when an organisation's treasury risk tolerance mode is changed.
  Records the new mode name, corresponding threshold, and timestamp for audit purposes.
  """
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :mode, :threshold, :changed_at]
  defstruct [:policy_id, :org_id, :mode, :threshold, :changed_at]
end
