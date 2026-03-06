defmodule Nexus.Treasury.Commands.ReverseReconciliation do
  @derive Jason.Encoder
  defstruct [
    :org_id,
    :reconciliation_id,
    :actor_email,
    :timestamp
  ]
end
