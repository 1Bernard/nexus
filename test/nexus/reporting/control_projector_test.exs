defmodule Nexus.Reporting.ControlProjectorTest do
  @moduledoc """
  Elite BDD tests for Compliance Reporting.
  """
  use Cabbage.Feature, async: false, file: "reporting/compliance_reporting.feature"
  use Nexus.DataCase

  alias Nexus.Reporting.Projectors.{
    LiquidityAccuracyProjector,
    EscalationIntegrityProjector,
    TransferPolicyProjector,
    SodProjector
  }

  alias Nexus.Reporting.Projections.{ControlMetric, ControlDrift}
  alias Nexus.Treasury.Events.{VaultBalanceSynced, ReconciliationProposed, TransferThresholdSet}

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(ControlMetric)
      Repo.delete_all(ControlDrift)
      Repo.delete_all(Nexus.Identity.Projections.User)
      # Reset version tracking to avoid idempotency skips
      Repo.delete_all("projection_versions")
    end)

    :ok
  end

  # --- Given ---

  defgiven ~r/^the compliance organization "(?<name>[^"]+)" exists$/, _args, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id}}
  end

  defgiven ~r/^a user "(?<email>[^"]+)" exists in the compliance organization$/,
           %{email: email},
           %{org_id: org_id} = state do
    user_id = Nexus.Schema.generate_uuidv7()

    unboxed_run(fn ->
      Repo.insert!(%Nexus.Identity.Projections.User{
        id: user_id,
        email: email,
        org_id: org_id,
        roles: ["guest"]
      })
    end)

    {:ok, Map.put(state, :user_id, user_id)}
  end

  defgiven ~r/^a transfer threshold for "(?<amount>[^"]+)" EUR is set$/,
           %{amount: amount},
           %{org_id: org_id} = state do
    event = %TransferThresholdSet{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      threshold: Decimal.new(amount),
      set_at: DateTime.utc_now()
    }

    metadata = %{
      event_id: Nexus.Schema.generate_uuidv7(),
      causation_id: Nexus.Schema.generate_uuidv7(),
      correlation_id: Nexus.Schema.generate_uuidv7(),
      handler_name: "Reporting.TransferPolicyProjector",
      event_number: 1
    }

    unboxed_run(fn ->
      TransferPolicyProjector.handle(event, metadata)
    end)

    {:ok, Map.put(state, :initial_threshold, amount)}
  end

  # --- When ---

  defwhen ~r/^a vault balance for "(?<amount>[^"]+)" EUR is synced$/,
          %{amount: amount},
          %{org_id: org_id} do
    event = %VaultBalanceSynced{
      org_id: org_id,
      vault_id: Nexus.Schema.generate_uuidv7(),
      amount: Decimal.new(amount),
      currency: "EUR",
      synced_at: DateTime.utc_now()
    }

    metadata = %{
      event_id: Nexus.Schema.generate_uuidv7(),
      causation_id: Nexus.Schema.generate_uuidv7(),
      correlation_id: Nexus.Schema.generate_uuidv7(),
      handler_name: "Reporting.LiquidityAccuracyProjector",
      event_number: 1
    }

    unboxed_run(fn ->
      LiquidityAccuracyProjector.handle(event, metadata)
    end)

    :ok
  end

  defwhen ~r/^a reconciliation for "(?<amount>[^"]+)" EUR with variance "(?<variance>[^"]+)" is proposed$/,
          %{amount: amount, variance: variance},
          %{org_id: org_id} do
    event = %ReconciliationProposed{
      org_id: org_id,
      reconciliation_id: Nexus.Schema.generate_uuidv7(),
      invoice_id: Nexus.Schema.generate_uuidv7(),
      statement_id: Nexus.Schema.generate_uuidv7(),
      statement_line_id: Nexus.Schema.generate_uuidv7(),
      amount: Decimal.new(amount),
      variance: Decimal.new(variance),
      actor_email: "auditor@nexus.xyz",
      currency: "EUR",
      timestamp: DateTime.utc_now()
    }

    metadata = %{
      event_id: Nexus.Schema.generate_uuidv7(),
      causation_id: Nexus.Schema.generate_uuidv7(),
      correlation_id: Nexus.Schema.generate_uuidv7(),
      handler_name: "Reporting.EscalationIntegrityProjector",
      event_number: 2
    }

    unboxed_run(fn ->
      EscalationIntegrityProjector.handle(event, metadata)
    end)

    :ok
  end

  defwhen ~r/^the transfer threshold for "(?<amount>[^"]+)" EUR is updated$/,
          %{amount: amount},
          %{org_id: org_id} do
    event = %TransferThresholdSet{
      policy_id: Nexus.Schema.generate_uuidv7(),
      org_id: org_id,
      threshold: Decimal.new(amount),
      set_at: DateTime.utc_now()
    }

    metadata = %{
      event_id: Nexus.Schema.generate_uuidv7(),
      causation_id: Nexus.Schema.generate_uuidv7(),
      correlation_id: Nexus.Schema.generate_uuidv7(),
      handler_name: "Reporting.TransferPolicyProjector",
      event_number: 2
    }

    unboxed_run(fn ->
      TransferPolicyProjector.handle(event, metadata)
    end)

    :ok
  end

  defwhen ~r/^a user is assigned both "(?<role1>[^"]+)" and "(?<role2>[^"]+)" roles$/,
          %{role1: r1, role2: r2},
          %{org_id: org_id} do
    user_id = Nexus.Schema.generate_uuidv7()

    # Pre-insert user since SodProjector calls list_sod_conflicts which queries Users
    unboxed_run(fn ->
      Repo.insert!(%Nexus.Identity.Projections.User{
        id: user_id,
        email: "toxic@nexus.ai",
        org_id: org_id,
        roles: [r1, r2]
      })
    end)

    event = %Nexus.Identity.Events.UserRoleChanged{
      org_id: org_id,
      user_id: user_id,
      role: r1,
      actor_id: Nexus.Schema.generate_uuidv7(),
      changed_at: DateTime.utc_now()
    }

    metadata = %{
      event_id: Nexus.Schema.generate_uuidv7(),
      causation_id: Nexus.Schema.generate_uuidv7(),
      correlation_id: Nexus.Schema.generate_uuidv7(),
      handler_name: "Reporting.SodProjector",
      event_number: 1
    }

    unboxed_run(fn ->
      SodProjector.handle(event, metadata)
    end)

    :ok
  end

  # --- Then ---

  defthen ~r/^(a|an) compliance "(?<key>[^"]+)" metric with score "(?<score>[^"]+)" should be projected$/,
          %{key: key, score: score},
          %{org_id: org_id} do
    unboxed_run(fn ->
      metric =
        Repo.one(
          from m in ControlMetric,
            where: m.org_id == ^org_id and m.metric_key == ^key,
            order_by: [desc: m.created_at],
            limit: 1
        )

      assert metric != nil
      assert Decimal.equal?(metric.score, Decimal.new(score))
    end)

    :ok
  end

  defthen ~r/^a drift score of "(?<score>[^"]+)" should be recorded$/,
          %{score: score},
          %{org_id: org_id} do
    unboxed_run(fn ->
      drift =
        Repo.one(
          from d in ControlDrift,
            where: d.org_id == ^org_id and d.control_key == "transfer_threshold",
            order_by: [desc: d.last_changed_at],
            limit: 1
        )

      assert drift != nil
      assert Decimal.equal?(drift.drift_score, Decimal.new(score))
    end)

    :ok
  end
end
