defmodule Nexus.Reporting.SamplingTest do
  use Cabbage.Feature, file: "reporting/audit_sampling.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Reporting
  alias Nexus.Reporting.Projections.AuditLog
  alias Nexus.Repo

  setup do
    org_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Repo.delete_all(AuditLog)
      Nexus.Repo.delete_all("projection_versions")
    end)

    {:ok, %{org_id: org_id}}
  end

  # --- Given ---

  defgiven ~r/^the audit log contains "(?<count>\d+)" recorded events$/, %{count: count_str}, state do
    count = String.to_integer(count_str)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      for i <- 1..count do
        Repo.insert!(%AuditLog{
          id: Nexus.Schema.generate_uuidv7(),
          org_id: state.org_id,
          event_type: "event_#{i}",
          actor_email: "user_#{i}@nexus.ai",
          details: %{},
          recorded_at: DateTime.utc_now()
        })
      end
    end)

    {:ok, state}
  end

  defgiven ~r/^the audit log contains events for "EUR" and "USD"$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^some events have an amount greater than "(?<threshold>\d+)"$/,
           %{threshold: threshold_str},
           state do
    threshold = String.to_integer(threshold_str)

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      # Insert one high-value and one low-value
      Repo.insert!(%AuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: state.org_id,
        event_type: "transfer_executed",
        actor_email: "trader1@nexus.ai",
        details: %{"amount" => threshold + 50000},
        recorded_at: DateTime.utc_now()
      })

      Repo.insert!(%AuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: state.org_id,
        event_type: "transfer_executed",
        actor_email: "trader2@nexus.ai",
        details: %{"amount" => threshold - 50000},
        recorded_at: DateTime.utc_now()
      })
    end)

    {:ok, state}
  end

  defgiven ~r/^the audit log contains "(?<event1>[^"]+)" and "(?<event2>[^"]+)" events$/,
           %{event1: e1, event2: e2},
           state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.insert!(%AuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: state.org_id,
        event_type: e1,
        actor_email: "admin@nexus.ai",
        details: %{},
        recorded_at: DateTime.utc_now()
      })

      Repo.insert!(%AuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: state.org_id,
        event_type: e2,
        actor_email: "system@nexus.ai",
        details: %{},
        recorded_at: DateTime.utc_now()
      })
    end)

    {:ok, state}
  end

  # --- When ---

  defwhen ~r/^I request a "(?<method>[^"]+)" sample of size "(?<size>\d+)"$/,
          %{method: method, size: size},
          state do
    sample = Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Reporting.generate_audit_sample(state.org_id, %{"method" => method, "size" => size})
    end)
    {:ok, Map.put(state, :sample, sample)}
  end

  defwhen ~r/^I request a "high_value" sample with threshold "(?<threshold>\d+)"$/,
          %{threshold: threshold},
          state do
    sample = Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Reporting.generate_audit_sample(state.org_id, %{
        "method" => "high_value",
        "size" => "10",
        "threshold" => threshold
      })
    end)

    {:ok, Map.put(state, :sample, sample)}
  end

  defwhen ~r/^I request a "risk_based" sample$/, _vars, state do
    sample = Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Reporting.generate_audit_sample(state.org_id, %{"method" => "risk_based", "size" => "10"})
    end)
    {:ok, Map.put(state, :sample, sample)}
  end

  # --- Then ---

  defthen ~r/^I should receive "(?<expected>\d+)" events in the sample$/,
          %{expected: expected_str},
          state do
    expected = String.to_integer(expected_str)
    assert length(state.sample) == expected
    {:ok, state}
  end

  defthen ~r/^only events with amount greater than or equal to "(?<threshold>\d+)" should be returned$/,
          %{threshold: threshold_str},
          state do
    threshold = String.to_integer(threshold_str)
    assert Enum.all?(state.sample, fn s -> s.details["amount"] >= threshold end)
    {:ok, state}
  end

  defthen ~r/^the sample should prioritize critical security events$/, _vars, state do
    event_types = Enum.map(state.sample, & &1.event_type)
    assert "security_step_up_verified" in event_types
    assert "tenant_suspended" in event_types
    {:ok, state}
  end
end
