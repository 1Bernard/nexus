defmodule Nexus.Reporting.ControlProjectorTest do
  @moduledoc """
  Elite BDD tests for Compliance Reporting.
  """
  use Cabbage.Feature, async: false, file: "reporting/compliance_reporting.feature"
  use Nexus.DataCase

  alias Nexus.Reporting.Projectors.ControlProjector
  alias Nexus.Reporting.Projections.ControlMetric
  alias Nexus.Treasury.Events.{VaultBalanceSynced, ReconciliationProposed}

  @moduletag :no_sandbox

  setup do
    unboxed_run(fn ->
      Repo.delete_all(ControlMetric)
    end)
    :ok
  end

  # --- Given ---

  defgiven ~r/^an organization "(?<name>[^"]+)" exists$/, _args, _state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, %{org_id: org_id}}
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
      handler_name: "Reporting.ControlProjector",
      event_number: 1
    }

    unboxed_run(fn ->
      Ecto.Multi.new()
      |> ControlProjector.project_metric(org_id, "liquidity_accuracy", 0.98, metadata, %{
        actual_balance: event.amount,
        synced_at: event.synced_at
      })
      |> Repo.transaction()
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
      handler_name: "Reporting.ControlProjector",
      event_number: 2
    }

    unboxed_run(fn ->
      Ecto.Multi.new()
      |> ControlProjector.project_metric(org_id, "escalation_integrity", 1.0, metadata, %{
        action: "reconciliation_proposed",
        reconciliation_id: event.reconciliation_id,
        variance: event.variance
      })
      |> Repo.transaction()
    end)

    :ok
  end

  # --- Then ---

  defthen ~r/^(a|an) "(?<key>[^"]+)" metric with score "(?<score>[^"]+)" should be projected$/,
          %{key: key, score: score},
          %{org_id: org_id} do
    unboxed_run(fn ->
      metric =
        Repo.one(from m in ControlMetric,
          where: m.org_id == ^org_id and m.metric_key == ^key,
          order_by: [desc: m.created_at],
          limit: 1
        )

      assert metric != nil
      assert Decimal.equal?(metric.score, Decimal.new(score))
    end)
    :ok
  end
end
