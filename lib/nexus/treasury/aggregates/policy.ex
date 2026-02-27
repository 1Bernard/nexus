defmodule Nexus.Treasury.Aggregates.Policy do
  @moduledoc """
  Aggregate for managing Treasury-specific policies — thresholds and named risk tolerance modes.
  """
  defstruct [:id, :org_id, :transfer_threshold, :mode]

  alias Nexus.Treasury.Commands.{SetTransferThreshold, EvaluateExposurePolicy, SetPolicyMode}
  alias Nexus.Treasury.Events.{TransferThresholdSet, PolicyAlertTriggered, PolicyModeChanged}

  @valid_modes ~w[standard strict relaxed]

  def execute(%__MODULE__{} = _state, %SetTransferThreshold{} = cmd) do
    %TransferThresholdSet{
      policy_id: cmd.policy_id,
      org_id: cmd.org_id,
      threshold: cmd.threshold,
      set_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{} = _state, %SetPolicyMode{mode: mode} = cmd)
      when mode in @valid_modes do
    %PolicyModeChanged{
      policy_id: cmd.policy_id,
      org_id: cmd.org_id,
      mode: cmd.mode,
      threshold: cmd.threshold,
      changed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{} = _state, %SetPolicyMode{mode: invalid_mode}) do
    {:error,
     {:invalid_mode, "#{invalid_mode} is not a valid policy mode. Use: standard, strict, relaxed"}}
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

  def apply(%__MODULE__{} = state, %PolicyModeChanged{} = ev) do
    %__MODULE__{
      state
      | id: ev.policy_id,
        org_id: ev.org_id,
        mode: ev.mode,
        transfer_threshold: ev.threshold
    }
  end

  def apply(%__MODULE__{} = state, %PolicyAlertTriggered{} = _ev) do
    # Alerts do not mutate policy state — they are read-side concerns
    state
  end

  def apply(%__MODULE__{} = state, _unknown_event) do
    # Ignore events from other domains that share this aggregate stream ID.
    # The Policy aggregate uses org_id as its identity, so Commanded may replay
    # cross-domain events (e.g. TenantProvisioned) when loading the stream.
    state
  end
end
