defmodule Nexus.Treasury.Events.TransferThresholdSet do
  @moduledoc """
  Event emitted when an organisation's biometric transfer threshold is updated.
  """
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :threshold, :set_at]
  defstruct [:policy_id, :org_id, :threshold, :set_at]
end
