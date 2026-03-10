defmodule Nexus.ERP.Aggregates.InvoiceTest do
  use ExUnit.Case, async: true

  alias Nexus.ERP.Aggregates.Invoice
  alias Nexus.ERP.Commands.{IngestInvoice, MatchInvoice}
  alias Nexus.ERP.Events.{InvoiceIngested, InvoiceMatched}

  @org_id "org-123"
  @invoice_id "inv-456"

  describe "MatchInvoice" do
    test "matches an ingested invoice" do
      state = %Invoice{id: @invoice_id, status: :ingested}
      cmd = %MatchInvoice{
        invoice_id: @invoice_id,
        org_id: @org_id,
        matched_type: "bulk_payment",
        matched_id: "batch-789",
        matched_at: DateTime.utc_now()
      }

      event = Invoice.execute(state, cmd)

      assert %InvoiceMatched{} = event
      assert event.invoice_id == @invoice_id
      assert event.matched_type == "bulk_payment"
      assert event.matched_id == "batch-789"
    end

    test "is idempotent for already matched invoice" do
      state = %Invoice{id: @invoice_id, status: :matched}
      cmd = %MatchInvoice{
        invoice_id: @invoice_id,
        org_id: @org_id,
        matched_type: "bulk_payment",
        matched_id: "batch-789"
      }

      assert Invoice.execute(state, cmd) == []
    end
  end

  describe "apply/2" do
    test "updates state to matched" do
      state = %Invoice{status: :ingested}
      event = %InvoiceMatched{
        invoice_id: @invoice_id,
        org_id: @org_id,
        matched_type: "bulk_payment",
        matched_id: "batch-789",
        matched_at: DateTime.utc_now()
      }

      new_state = Invoice.apply(state, event)

      assert new_state.id == @invoice_id
      assert new_state.status == :matched
    end
  end
end
