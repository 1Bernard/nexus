defmodule Nexus.Treasury.PolicyModeTest do
  use Cabbage.Feature, file: "treasury/policy_mode.feature"
  use Nexus.DataCase

  @moduletag :feature
  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.{SetPolicyMode, EvaluateExposurePolicy, SetTransferThreshold}
  alias Nexus.Treasury.Events.{PolicyModeChanged, TransferThresholdSet, PolicyAlertTriggered}
  alias Nexus.Treasury.Projectors.PolicyProjector
  alias Nexus.Treasury.Projections.{TreasuryPolicy, PolicyAlert}

  @mode_thresholds %{
    "standard" => Decimal.new("1000000"),
    "strict" => Decimal.new("50000"),
    "relaxed" => Decimal.new("10000000")
  }

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      Nexus.Repo.delete_all(PolicyAlert)
      Nexus.Repo.delete_all(TreasuryPolicy)

      Nexus.Repo.delete_all(
        from p in "projection_versions",
          where: p.projection_name in ["Treasury.PolicyProjector"]
      )
    end)

    {:ok, %{org_id: Ecto.UUID.generate()}}
  end

  # --- Given ---

  defgiven ~r/^the organization "(?<name>[^"]+)" has no policy mode set$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^the organization "(?<name>[^"]+)" is on "(?<mode>[^"]+)" mode$/,
           %{mode: mode},
           state do
    threshold = Map.fetch!(@mode_thresholds, mode)

    cmd = %SetPolicyMode{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %PolicyModeChanged{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold,
      changed_at: DateTime.utc_now()
    }

    project_event(event, 1)

    {:ok, Map.merge(state, %{mode: mode, threshold: threshold})}
  end

  defgiven ~r/^the strict mode threshold is "(?<threshold>[^"]+)"$/,
           %{threshold: threshold},
           state do
    {:ok, Map.put(state, :threshold, Decimal.new(threshold))}
  end

  # --- When ---

  defwhen ~r/^the treasury manager selects "(?<mode>[^"]+)" mode$/, %{mode: mode}, state do
    threshold = Map.fetch!(@mode_thresholds, mode)

    cmd = %SetPolicyMode{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %PolicyModeChanged{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold,
      changed_at: DateTime.utc_now()
    }

    project_event(event, 1)

    {:ok, Map.merge(state, %{mode: mode, threshold: threshold})}
  end

  defwhen ~r/^the treasury manager switches to "(?<mode>[^"]+)" mode$/, %{mode: mode}, state do
    threshold = Map.fetch!(@mode_thresholds, mode)

    cmd = %SetPolicyMode{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold
    }

    assert :ok == Nexus.App.dispatch(cmd)

    event = %PolicyModeChanged{
      policy_id: state.org_id,
      org_id: state.org_id,
      mode: mode,
      threshold: threshold,
      changed_at: DateTime.utc_now()
    }

    # Event number 2 because the Given step already wrote event 1
    project_event(event, 2)

    {:ok, Map.merge(state, %{mode: mode, threshold: threshold})}
  end

  defwhen ~r/^the system evaluates an exposure of "(?<amount>[^"]+)" EUR\/USD$/,
          %{amount: amount},
          state do
    # First set the threshold via SetTransferThreshold so EvaluateExposurePolicy can read it
    threshold_cmd = %SetTransferThreshold{
      policy_id: state.org_id,
      org_id: state.org_id,
      threshold: state.threshold
    }

    assert :ok == Nexus.App.dispatch(threshold_cmd)

    threshold_event = %TransferThresholdSet{
      policy_id: state.org_id,
      org_id: state.org_id,
      threshold: state.threshold,
      set_at: DateTime.utc_now()
    }

    project_event(threshold_event, 2)

    exposure_amount = Decimal.new(amount)

    evaluate_cmd = %EvaluateExposurePolicy{
      policy_id: state.org_id,
      org_id: state.org_id,
      currency_pair: "EUR/USD",
      exposure_amount: exposure_amount
    }

    assert :ok == Nexus.App.dispatch(evaluate_cmd)

    if Decimal.gt?(exposure_amount, state.threshold) do
      alert_event = %PolicyAlertTriggered{
        policy_id: state.org_id,
        org_id: state.org_id,
        currency_pair: "EUR/USD",
        exposure_amount: exposure_amount,
        threshold: state.threshold,
        triggered_at: DateTime.utc_now()
      }

      project_event(alert_event, 3)
    end

    {:ok, Map.put(state, :exposure_amount, exposure_amount)}
  end

  # --- Then ---

  defthen ~r/^the policy mode should be saved as "(?<mode>[^"]+)"$/, %{mode: mode}, state do
    policy = get_policy(state.org_id)
    refute is_nil(policy)
    assert policy.mode == mode
    {:ok, state}
  end

  defthen ~r/^the transfer threshold should be "(?<threshold>[^"]+)"$/,
          %{threshold: threshold},
          state do
    policy = get_policy(state.org_id)
    refute is_nil(policy)
    assert Decimal.eq?(policy.transfer_threshold, Decimal.new(threshold))
    {:ok, state}
  end

  defthen ~r/^a policy alert should be triggered$/, _vars, state do
    alerts = get_alerts(state.org_id)
    refute Enum.empty?(alerts)
    {:ok, state}
  end

  # --- Helpers ---

  defp project_event(event, event_number) do
    metadata = %{
      handler_name: "Treasury.PolicyProjector",
      event_number: event_number
    }

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      PolicyProjector.handle(event, metadata)
    end)
  end

  defp get_policy(org_id) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      Nexus.Repo.one(from p in TreasuryPolicy, where: p.org_id == ^org_id)
    end)
  end

  defp get_alerts(org_id) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      import Ecto.Query
      Nexus.Repo.all(from a in PolicyAlert, where: a.org_id == ^org_id)
    end)
  end
end
