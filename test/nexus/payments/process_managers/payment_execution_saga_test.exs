defmodule Nexus.Payments.ProcessManagers.PaymentExecutionSagaTest do
  @moduledoc """
  Elite BDD tests for Payment Lifecycle Orchestration.
  """
  # Saga tests can be async if they are pure logic
  use Cabbage.Feature, async: true, file: "payments/payment_lifecycle.feature"

  alias Nexus.Payments.ProcessManagers.PaymentExecutionSaga
  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Payments.Commands.InitiateExternalPayment
  alias Nexus.Payments.Events.ExternalPaymentSettled

  # --- Given ---

  defgiven ~r/^a transfer of "(?<amount>[^"]+)" USD to "(?<to_curr>[^"]+)" has been executed$/,
           %{amount: amount, to_curr: to_curr},
           _state do
    event = %TransferExecuted{
      transfer_id: Nexus.Schema.generate_uuidv7(),
      org_id: Nexus.Schema.generate_uuidv7(),
      amount: Decimal.new(amount),
      from_currency: "USD",
      to_currency: to_curr,
      recipient_data: %{recipient_code: "RCP_789"},
      executed_at: DateTime.utc_now()
    }

    {:ok, %{event: event}}
  end

  defgiven ~r/^a payment execution saga in status "(?<status>[^"]+)"$/, %{status: status}, _state do
    saga = %PaymentExecutionSaga{
      transfer_id: Nexus.Schema.generate_uuidv7(),
      org_id: Nexus.Schema.generate_uuidv7(),
      status: String.to_atom(status)
    }

    {:ok, %{saga: saga}}
  end

  # --- When ---

  defwhen "the payment execution saga handles the transfer event", _args, %{event: event} do
    command = PaymentExecutionSaga.handle(%PaymentExecutionSaga{status: nil}, event)
    state = PaymentExecutionSaga.apply(%PaymentExecutionSaga{status: nil}, event)
    {:ok, %{command: command, saga: state}}
  end

  defwhen "the external payment is settled", _args, %{saga: saga} do
    event = %ExternalPaymentSettled{
      payment_id: "pay-#{saga.transfer_id}",
      org_id: saga.org_id,
      settled_at: DateTime.utc_now()
    }

    # apply the event
    new_saga = PaymentExecutionSaga.apply(saga, event)
    {:ok, %{saga: new_saga}}
  end

  # --- Then ---

  defthen ~r/^an external payment of "(?<amount>[^"]+)" (?<curr>[A-Z]{3}) should be initiated$/,
          %{amount: amount, curr: curr},
          %{command: command} do
    assert %InitiateExternalPayment{} = command
    assert Decimal.equal?(command.amount, Decimal.new(amount))
    assert command.currency == curr
    :ok
  end

  defthen ~r/^the saga status should be "(?<status>[^"]+)"$/, %{status: status}, %{saga: saga} do
    assert saga.status == String.to_atom(status)
    :ok
  end

  defthen "the saga should be stopped", _args, %{saga: saga} do
    assert PaymentExecutionSaga.stop?(saga)
    :ok
  end
end
