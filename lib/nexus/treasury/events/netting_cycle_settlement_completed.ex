defmodule Nexus.Treasury.Events.NettingCycleSettlementCompleted do
  @moduledoc """
  Event emitted when a netting cycle settlement is finalized.
  """
  @derive Jason.Encoder
  defstruct [:netting_id, :org_id, :completed_at]
end
