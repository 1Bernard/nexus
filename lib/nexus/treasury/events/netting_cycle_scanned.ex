defmodule Nexus.Treasury.Events.NettingCycleScanned do
  @moduledoc """
  Event emitted when a netting cycle scan completes.
  """
  @derive Jason.Encoder
  defstruct [
    :netting_id,
    :org_id,
    :invoice_count,
    :scanned_at
  ]
end
