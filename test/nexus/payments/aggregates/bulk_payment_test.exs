defmodule Nexus.Payments.Aggregates.BulkPaymentTest do
  use ExUnit.Case, async: true

  alias Nexus.Payments.Aggregates.BulkPayment
  alias Nexus.Payments.Commands.{InitiateBulkPayment, FinalizeBulkPayment}
  alias Nexus.Payments.Events.{BulkPaymentInitiated, BulkPaymentCompleted}

  describe "execute/2" do
    test "initiates a bulk payment batch" do
      bulk_payment_id = Nexus.Schema.generate_uuidv7()
      org_id = Nexus.Schema.generate_uuidv7()
      user_id = Nexus.Schema.generate_uuidv7()
      initiated_at = DateTime.utc_now()

      payments = [
        %{
          amount: Decimal.new("100.00"),
          currency: "EUR",
          recipient_name: "Vendor A",
          recipient_account: "ACC1"
        },
        %{
          amount: Decimal.new("250.50"),
          currency: "EUR",
          recipient_name: "Vendor B",
          recipient_account: "ACC2"
        }
      ]

      cmd = %InitiateBulkPayment{
        bulk_payment_id: bulk_payment_id,
        org_id: org_id,
        user_id: user_id,
        payments: payments,
        initiated_at: initiated_at
      }

      event = BulkPayment.execute(%BulkPayment{}, cmd)

      assert %BulkPaymentInitiated{} = event
      assert event.bulk_payment_id == bulk_payment_id
      assert Decimal.eq?(event.total_amount, Decimal.new("350.50"))
      assert event.count == 2
      assert event.payments == payments
    end

    test "finalizes a bulk payment batch" do
      bulk_payment_id = Nexus.Schema.generate_uuidv7()
      org_id = Nexus.Schema.generate_uuidv7()
      completed_at = DateTime.utc_now()

      state = %BulkPayment{id: bulk_payment_id, org_id: org_id, status: :initiated}

      cmd = %FinalizeBulkPayment{
        bulk_payment_id: bulk_payment_id,
        org_id: org_id,
        completed_at: completed_at
      }

      event = BulkPayment.execute(state, cmd)

      assert %BulkPaymentCompleted{} = event
      assert event.bulk_payment_id == bulk_payment_id
      assert event.completed_at == completed_at
    end
  end

  describe "apply/2" do
    test "updates state after initiation" do
      id = Nexus.Schema.generate_uuidv7()
      event = %BulkPaymentInitiated{
        bulk_payment_id: id,
        org_id: Nexus.Schema.generate_uuidv7(),
        user_id: Nexus.Schema.generate_uuidv7(),
        payments: [],
        total_amount: Decimal.new("0"),
        count: 5,
        initiated_at: DateTime.utc_now()
      }

      state = BulkPayment.apply(%BulkPayment{}, event)

      assert state.id == id
      assert state.status == :initiated
      assert state.total_items == 5
      assert state.processed_items == 0
    end

    test "updates state after completion" do
      state = %BulkPayment{status: :initiated}

      event = %BulkPaymentCompleted{
        bulk_payment_id: "batch-1",
        org_id: "org-1",
        completed_at: DateTime.utc_now()
      }

      state = BulkPayment.apply(state, event)

      assert state.status == :completed
    end
  end
end
