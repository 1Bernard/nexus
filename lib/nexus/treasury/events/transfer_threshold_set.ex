defmodule Nexus.Treasury.Events.TransferThresholdSet do
  @moduledoc """
  Event emitted when an organization's biometric threshold is updated.
  """
  @derive Jason.Encoder
  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
