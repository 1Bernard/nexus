defmodule Nexus.Treasury.ReconciliationPerformanceTest do
  use Nexus.DataCase
  alias Nexus.Treasury.ProcessManagers.ReconciliationManager
  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.Treasury.Commands.ReconcileTransaction

  test "matching performs O(1) under load (1000 items)" do
    org_id = Nexus.Schema.generate_uuidv7()

    # 1. Seed the manager with 1000 noisy invoices
    pm = Enum.reduce(1..1000, %ReconciliationManager{org_id: org_id}, fn i, acc ->
      event = %InvoiceIngested{
        org_id: org_id,
        invoice_id: "INV-NOISE-#{i}",
        amount: Decimal.new(i),
        currency: "USD"
      }
      ReconciliationManager.apply(acc, event)
    end)

    # 2. Add one matching statement line to the state
    matching_amount = Decimal.new("9999.99")
    line_id = "STMT-LINE-MATCH"
    pm = ReconciliationManager.apply(pm, %Nexus.ERP.Events.StatementUploaded{
      org_id: org_id,
      statement_id: "STMT-123",
      lines: [%{id: line_id, amount: Decimal.negate(matching_amount), currency: "USD"}]
    })

    # 3. Handle a new invoice that matches the line
    event = %InvoiceIngested{
      org_id: org_id,
      invoice_id: "INV-MATCH",
      amount: matching_amount,
      currency: "USD"
    }

    {duration_us, result} = :timer.tc(fn ->
      ReconciliationManager.handle(pm, event)
    end)

    # Convert to milliseconds
    duration_ms = duration_us / 1000

    IO.puts("\n>>> Match Engine Latency: #{duration_ms}ms")

    assert %ReconcileTransaction{
      invoice_id: "INV-MATCH",
      statement_line_id: ^line_id,
      amount: ^matching_amount
    } = result

    # Standard: Must be sub-millisecond for O(1) lookup in memory
    assert duration_ms < 1.0
  end
end
