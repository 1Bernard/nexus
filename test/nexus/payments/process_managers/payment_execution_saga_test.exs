defmodule Nexus.Payments.ProcessManagers.PaymentExecutionSagaTest do
  use ExUnit.Case, async: true
  alias Nexus.Payments.ProcessManagers.PaymentExecutionSaga
  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Payments.Commands.InitiateExternalPayment
  alias Nexus.Payments.Events.ExternalPaymentSettled

  describe "handle/2" do
    test "dispatches InitiateExternalPayment on TransferExecuted" do
      event = %TransferExecuted{
        transfer_id: "tx123",
        org_id: "org1",
        amount: Decimal.new(1000),
        from_currency: "USD",
        to_currency: "EUR",
        recipient_data: %{recipient_code: "RCP_123"},
        executed_at: DateTime.utc_now()
      }

      command = PaymentExecutionSaga.handle(%PaymentExecutionSaga{status: nil}, event)

      assert %InitiateExternalPayment{
               transfer_id: "tx123",
               amount: amount,
               currency: "EUR",
               recipient_data: %{recipient_code: "RCP_123"}
             } = command
      assert Decimal.equal?(amount, 1000)
    end

    test "handle/2 returns empty list on ExternalPaymentSettled" do
      event = %ExternalPaymentSettled{payment_id: "pay-1", org_id: "org1", settled_at: DateTime.utc_now()}
      assert [] == PaymentExecutionSaga.handle(%PaymentExecutionSaga{}, event)
    end
  end

  describe "apply/2" do
    test "transitions state on TransferExecuted" do
      event = %TransferExecuted{
        transfer_id: "tx123",
        org_id: "org1",
        amount: Decimal.new(1000),
        from_currency: "USD",
        to_currency: "EUR",
        executed_at: DateTime.utc_now()
      }

      state = PaymentExecutionSaga.apply(%PaymentExecutionSaga{}, event)
      assert state.transfer_id == "tx123"
      assert state.status == :transfer_executed
    end
  end

  describe "stop?/1" do
    test "returns true when status is :settled" do
      assert PaymentExecutionSaga.stop?(%PaymentExecutionSaga{status: :settled})
    end

    test "returns true when status is :failed" do
      assert PaymentExecutionSaga.stop?(%PaymentExecutionSaga{status: :failed})
    end

    test "returns false for other statuses" do
      refute PaymentExecutionSaga.stop?(%PaymentExecutionSaga{status: :transfer_executed})
      refute PaymentExecutionSaga.stop?(%PaymentExecutionSaga{status: nil})
    end
  end
end
