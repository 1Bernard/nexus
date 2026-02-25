defmodule Nexus.Treasury.Aggregates.Policy do
  @moduledoc """
  Aggregate for managing Treasury-specific policies (thresholds, etc).
  """
  defstruct [:id, :org_id, :transfer_threshold]

  alias Nexus.Treasury.Commands.SetTransferThreshold
  alias Nexus.Treasury.Events.TransferThresholdSet

  def execute(%__MODULE__{}, %SetTransferThreshold{} = cmd) do
    %TransferThresholdSet{
      policy_id: cmd.policy_id,
      org_id: cmd.org_id,
      threshold: cmd.threshold,
      set_at: DateTime.utc_now()
    }
  end

  def apply(%__MODULE__{} = state, %TransferThresholdSet{} = ev) do
    %__MODULE__{
      state
      | id: ev.policy_id,
        org_id: ev.org_id,
        transfer_threshold: ev.threshold
    }
  end
end
