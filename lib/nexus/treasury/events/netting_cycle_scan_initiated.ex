defmodule Nexus.Treasury.Events.NettingCycleScanInitiated do
  @moduledoc """
  Event emitted when a netting cycle scan is triggered.
  """
  @derive Jason.Encoder
  defstruct [
    :netting_id,
    :org_id,
    :user_id
  ]
end
