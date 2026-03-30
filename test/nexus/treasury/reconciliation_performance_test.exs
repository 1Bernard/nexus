defmodule Nexus.Treasury.ReconciliationPerformanceTest do
  @moduledoc """
  Performance-focused Elite BDD tests for the Match Engine.
  """
  use Cabbage.Feature, file: "treasury/reconciliation_performance.feature"
  use Nexus.DataCase

  alias Nexus.Treasury.ProcessManagers.ReconciliationManager
  alias Nexus.ERP.Events.{InvoiceIngested, StatementUploaded}
  alias Nexus.Treasury.Commands.ReconcileTransaction

  @moduletag :no_sandbox

  defgiven ~r/^the match engine is seeded with "(?<count>\d+)" invoices$/, %{count: count_str}, _state do
    count = String.to_integer(count_str)
    org_id = Nexus.Schema.generate_uuidv7()

    # Seed the manager with noisy invoices
    pm =
      Enum.reduce(1..count, %ReconciliationManager{org_id: org_id}, fn i, acc ->
        event = %InvoiceIngested{
          org_id: org_id,
          invoice_id: "INV-NOISE-#{i}",
          amount: Decimal.new(i),
          currency: "USD"
        }

        ReconciliationManager.apply(acc, event)
      end)

    {:ok, %{pm: pm, org_id: org_id}}
  end

  defgiven ~r/^a statement with a line for "(?<amount>[^"]+)" exists$/,
           %{amount: amount_str},
           %{pm: pm, org_id: org_id} do
    amount = Nexus.Schema.parse_decimal_safe(amount_str)
    line_id = "STMT-LINE-MATCH"

    pm =
      ReconciliationManager.apply(pm, %StatementUploaded{
        org_id: org_id,
        statement_id: "STMT-123",
        lines: [%{id: line_id, amount: amount, currency: "USD"}]
      })

    {:ok, %{pm: pm, match_amount: Decimal.negate(amount), line_id: line_id}}
  end

  defwhen ~r/^a new invoice for "(?<amount>[^"]+)" is ingested$/,
          %{amount: amount_str},
          %{pm: pm, org_id: org_id} do
    amount = Nexus.Schema.parse_decimal_safe(amount_str)

    event = %InvoiceIngested{
      org_id: org_id,
      invoice_id: "INV-MATCH",
      amount: amount,
      currency: "USD"
    }

    {duration_us, result} =
      :timer.tc(fn ->
        ReconciliationManager.handle(pm, event)
      end)

    {:ok, %{result: result, duration_ms: duration_us / 1000}}
  end

  defthen "the invoice should be matched in sub-millisecond time", _args, %{duration_ms: ms} do
    IO.puts("\n>>> Match Engine Latency (1000 items): #{ms}ms")
    assert ms < 1.0
    :ok
  end

  defthen "a reconciliation command should be dispatched", _args, %{
    result: result,
    match_amount: amount,
    line_id: line_id
  } do
    assert %ReconcileTransaction{
             invoice_id: "INV-MATCH",
             statement_line_id: ^line_id,
             amount: ^amount
           } = result

    :ok
  end
end
