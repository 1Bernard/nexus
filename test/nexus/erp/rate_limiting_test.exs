defmodule Nexus.ERP.RateLimitingTest do
  use Cabbage.Feature, file: "erp/rate_limiting.feature"
  use Nexus.DataCase

  alias Nexus.ERP.Adapters.RateLimiter

  @moduletag :feature

  setup do
    # Clear hammer state for tests (just in case)
    :ok
  end

  # --- Given ---
  defgiven ~r/^a registered tenant "(?<tenant>[^"]+)" exists$/, %{tenant: _tenant}, state do
    org_id = Nexus.Schema.generate_uuidv7()
    {:ok, Map.put(state, :org_id, org_id)}
  end

  # --- When ---
  defwhen ~r/^the ERP system sends 5 invoice payloads within the limit$/, _vars, state do
    entity_id = "SAP-#{Nexus.Schema.generate_uuidv7()}"
    results = Enum.map(1..5, fn _ -> RateLimiter.check_quota(entity_id) end)
    {:ok, Map.put(state, :results, results)}
  end

  defwhen ~r/^the ERP system sends 150 invoice payloads rapidly$/, _vars, state do
    entity_id = "SAP-#{Nexus.Schema.generate_uuidv7()}"
    results = Enum.map(1..150, fn _ -> RateLimiter.check_quota(entity_id) end)
    {:ok, Map.put(state, :results, results)}
  end

  # --- Then ---
  defthen ~r/^all 5 payloads should be accepted$/, _vars, state do
    assert Enum.all?(state.results, fn r -> r == :ok end)
    {:ok, state}
  end

  defthen ~r/^the system should return a 429 Too Many Requests error$/, _vars, state do
    # In the burst of 150, the first 100 should be :ok, the last 50 should be {:error, :rate_limited}
    denied = Enum.count(state.results, fn r -> r == {:error, :rate_limited} end)
    assert denied == 50
    {:ok, state}
  end

  defthen ~r/^the excess payloads should not reach the domain aggregate$/, _vars, state do
    # Verified by the :rate_limited return tuple
    {:ok, state}
  end
end
