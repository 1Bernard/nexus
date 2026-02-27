defmodule Nexus.Treasury.Aggregates.Policy do
  @moduledoc """
  Aggregate for managing Treasury-specific policies (thresholds, etc).
  """
  defstruct [:id, :org_id, :transfer_threshold]

  alias Nexus.Treasury.Commands.{SetTransferThreshold, EvaluateExposurePolicy}
  alias Nexus.Treasury.Events.{TransferThresholdSet, PolicyAlertTriggered}

  def execute(%__MODULE__{} = _state, %SetTransferThreshold{} = cmd) do
    %TransferThresholdSet{
      policy_id: cmd.policy_id,
      org_id: cmd.org_id,
      threshold: cmd.threshold,
      set_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{} = state, %EvaluateExposurePolicy{} = cmd) do
    # Compare current exposure against the stored threshold
    threshold = state.transfer_threshold || Decimal.new("100000")

    if Decimal.gt?(cmd.exposure_amount, threshold) do
      %PolicyAlertTriggered{
        policy_id: state.id,
        org_id: state.org_id,
        currency_pair: cmd.currency_pair,
        exposure_amount: cmd.exposure_amount,
        threshold: threshold,
        triggered_at: DateTime.utc_now()
      }
    else
      []
    end
  end

  def apply(%__MODULE__{} = state, %TransferThresholdSet{} = ev) do
    %__MODULE__{
      state
      | id: ev.policy_id,
        org_id: ev.org_id,
        transfer_threshold: ev.threshold
    }
  end

  def apply(%__MODULE__{} = state, %PolicyAlertTriggered{} = _ev) do
    # Alerts don't necessarily mutate the policy state itself
    state
  end
end
