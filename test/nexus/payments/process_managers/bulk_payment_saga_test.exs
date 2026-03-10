defmodule Nexus.Payments.ProcessManagers.BulkPaymentSagaTest do
  use ExUnit.Case, async: true

  alias Nexus.Payments.ProcessManagers.BulkPaymentSaga
  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Treasury.Events.TransferInitiated
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Payments.Commands.FinalizeBulkPayment

  describe "handle/2" do
    test "dispatches individual RequestTransfer commands for each payment" do
      bulk_payment_id = "batch-1"
      org_id = "org-1"
      user_id = "user-1"
      
      payments = [
        %{amount: Decimal.new("100.00"), currency: "EUR"},
        %{amount: Decimal.new("200.00"), currency: "USD"}
      ]

      event = %BulkPaymentInitiated{
        bulk_payment_id: bulk_payment_id,
        org_id: org_id,
        user_id: user_id,
        payments: payments,
        total_amount: Decimal.new("300.00"),
        count: 2,
        initiated_at: DateTime.utc_now()
      }

      commands = BulkPaymentSaga.handle(%BulkPaymentSaga{}, event)

      assert is_list(commands)
      assert length(commands) == 2
      
      [cmd1, cmd2] = commands
      
      assert %RequestTransfer{} = cmd1
      assert cmd1.bulk_payment_id == bulk_payment_id
      assert cmd1.amount == Decimal.new("100.00")
      assert cmd1.from_currency == "EUR"

      assert %RequestTransfer{} = cmd2
      assert cmd2.bulk_payment_id == bulk_payment_id
      assert cmd2.amount == Decimal.new("200.00")
      assert cmd2.from_currency == "USD"
    end

    test "dispatches MatchInvoice command when invoice_id is present" do
      bulk_payment_id = "batch-1"
      org_id = "org-1"
      user_id = "user-1"
      invoice_id = "inv-abc"
      
      payments = [
        %{amount: Decimal.new("100.00"), currency: "EUR", invoice_id: invoice_id}
      ]

      event = %BulkPaymentInitiated{
        bulk_payment_id: bulk_payment_id,
        org_id: org_id,
        user_id: user_id,
        payments: payments,
        total_amount: Decimal.new("100.00"),
        count: 1,
        initiated_at: DateTime.utc_now()
      }

      commands = BulkPaymentSaga.handle(%BulkPaymentSaga{}, event)

      assert is_list(commands)
      # 1 RequestTransfer + 1 MatchInvoice
      assert length(commands) == 2
      
      assert Enum.any?(commands, fn cmd -> 
        match?(%Nexus.Treasury.Commands.RequestTransfer{amount: %Decimal{}}, cmd) and 
        Decimal.eq?(cmd.amount, Decimal.new("100.00"))
      end)

      assert Enum.any?(commands, fn cmd ->
        match?(%Nexus.ERP.Commands.MatchInvoice{invoice_id: ^invoice_id, matched_id: ^bulk_payment_id}, cmd)
      end)
    end

    test "dispatches FinalizeBulkPayment when all items are processed" do
      bulk_payment_id = "batch-1"
      org_id = "org-1"
      
      # State shows 1 out of 2 processed
      saga = %BulkPaymentSaga{
        bulk_payment_id: bulk_payment_id,
        org_id: org_id,
        total_items: 2,
        processed_items: 1
      }

      event = %TransferInitiated{
        transfer_id: "tx-2",
        org_id: org_id,
        user_id: "user-1",
        from_currency: "EUR",
        to_currency: "USD",
        amount: Decimal.new("100.00"),
        status: :initiated,
        bulk_payment_id: bulk_payment_id,
        requested_at: DateTime.utc_now()
      }

      command = BulkPaymentSaga.handle(saga, event)

      assert %FinalizeBulkPayment{} = command
      assert command.bulk_payment_id == bulk_payment_id
    end
    
    test "returns empty list if batch is not yet complete" do
      saga = %BulkPaymentSaga{
        bulk_payment_id: "batch-1",
        org_id: "org-1",
        total_items: 5,
        processed_items: 1
      }

      event = %TransferInitiated{
        transfer_id: "tx-2",
        org_id: "org-1",
        user_id: "user-1",
        from_currency: "EUR",
        to_currency: "USD",
        amount: Decimal.new("100.00"),
        status: :initiated,
        bulk_payment_id: "batch-1",
        requested_at: DateTime.utc_now()
      }

      assert BulkPaymentSaga.handle(saga, event) == []
    end
  end

  describe "apply/2" do
    test "initializes saga state from BulkPaymentInitiated" do
      event = %BulkPaymentInitiated{
        bulk_payment_id: "batch-1",
        org_id: "org-1",
        user_id: "user-1",
        payments: [],
        total_amount: Decimal.new(0),
        count: 10,
        initiated_at: DateTime.utc_now()
      }

      state = BulkPaymentSaga.apply(%BulkPaymentSaga{}, event)

      assert state.bulk_payment_id == "batch-1"
      assert state.total_items == 10
      assert state.processed_items == 0
    end

    test "increments processed_items on TransferInitiated" do
      state = %BulkPaymentSaga{processed_items: 2}
      event = %TransferInitiated{
        transfer_id: "tx-2",
        org_id: "org-1",
        user_id: "user-1",
        from_currency: "EUR",
        to_currency: "USD",
        amount: Decimal.new("100.00"),
        status: :initiated,
        requested_at: DateTime.utc_now()
      }

      state = BulkPaymentSaga.apply(state, event)

      assert state.processed_items == 3
    end
  end
end
