defmodule Nexus.Treasury.Events.NettingCycleSettled do
  @moduledoc """
  Event emitted when a netting cycle's net positions have been calculated.
  """
  @derive Jason.Encoder
  defstruct [:netting_id, :org_id, :user_id, :net_positions, :invoice_ids, :settled_at]
end
