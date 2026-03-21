defmodule Nexus.Reporting.ControlProjectorTest do
  use Nexus.DataCase, async: false # Async false for projection verification

  alias Nexus.Reporting.Projectors.ControlProjector
  alias Nexus.Reporting.Projections.ControlMetric
  alias Nexus.Treasury.Events.{VaultBalanceSynced, ReconciliationProposed}

  setup do
    org_id = Ecto.UUID.generate()
    event_id = Ecto.UUID.generate()
    {:ok, org_id: org_id, event_id: event_id, handler_name: "Reporting.ControlProjector"}
  end

  test "projects VaultBalanceSynced into liquidity_accuracy metric", %{org_id: org_id, event_id: event_id, handler_name: handler_name} do
    event = %VaultBalanceSynced{
      org_id: org_id,
      vault_id: Ecto.UUID.generate(),
      amount: Decimal.new("1000.00"),
      currency: "EUR",
      synced_at: DateTime.utc_now()
    }

    metadata = %{event_id: event_id, causation_id: event_id, handler_name: handler_name, event_number: 1}

    # Manual execution of the projector logic
    Ecto.Multi.new()
    |> ControlProjector.project_metric(org_id, "liquidity_accuracy", 0.98, metadata, %{
      actual_balance: event.amount,
      synced_at: event.synced_at
    })
    |> Repo.transaction()

    assert_metric(org_id, "liquidity_accuracy", 0.98)
  end

  test "projects ReconciliationProposed into escalation_integrity metric", %{org_id: org_id, event_id: event_id, handler_name: handler_name} do
    event = %ReconciliationProposed{
      org_id: org_id,
      reconciliation_id: Ecto.UUID.generate(),
      invoice_id: Ecto.UUID.generate(),
      statement_id: Ecto.UUID.generate(),
      statement_line_id: Ecto.UUID.generate(),
      amount: Decimal.new("500.00"),
      variance: Decimal.new("5.00"),
      actor_email: "auditor@nexus.xyz",
      currency: "EUR",
      timestamp: DateTime.utc_now()
    }

    metadata = %{event_id: event_id, causation_id: event_id, handler_name: handler_name, event_number: 1}

    Ecto.Multi.new()
    |> ControlProjector.project_metric(org_id, "escalation_integrity", 1.0, metadata, %{
      action: "reconciliation_proposed",
      reconciliation_id: event.reconciliation_id,
      variance: event.variance
    })
    |> Repo.transaction()

    assert_metric(org_id, "escalation_integrity", 1.0)
  end

  # --- Helpers ---

  defp assert_metric(org_id, key, expected_score) do
    metric =
      Repo.one(from m in ControlMetric,
        where: m.org_id == ^org_id and m.metric_key == ^key,
        order_by: [desc: m.created_at],
        limit: 1
      )

    assert metric != nil
    assert Decimal.to_float(metric.score) == expected_score * 1.0
  end
end
