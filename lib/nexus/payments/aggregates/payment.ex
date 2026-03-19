defmodule Nexus.Payments.Aggregates.Payment do
  @moduledoc """
  Aggregate to manage the lifecycle of an external financial payment.
  """
  @derive Jason.Encoder
  defstruct [:id, :org_id, :transfer_id, :amount, :currency, :status, :external_reference]

  alias Nexus.Payments.Commands.{InitiateExternalPayment, SettleExternalPayment, FailExternalPayment}
  alias Nexus.Payments.Events.{ExternalPaymentInitiated, ExternalPaymentSettled, ExternalPaymentFailed}

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %InitiateExternalPayment{} = cmd) do
    # Call the gateway to initiate building the external record.
    # We do the API call INSIDE the handle (or preferably in a handler/saga).
    # In Commanded, side effects like API calls should happen in Handlers or Sagas.
    # So the aggregate just records the intent and the SAGA does the call.
    # HOWEVER, for a simple POC, we can emit the event and let the Saga call the API.

    # We'll follow the pattern: Aggregate emits Initiated -> Saga calls API -> Saga dispatches Settle/Fail.

    %ExternalPaymentInitiated{
      payment_id: cmd.payment_id,
      org_id: cmd.org_id,
      transfer_id: cmd.transfer_id,
      amount: cmd.amount,
      currency: cmd.currency,
      recipient_data: cmd.recipient_data,
      external_reference: nil, # Will be filled by the gateway later
      initiated_at: cmd.initiated_at
    }
  end

  def execute(%__MODULE__{status: :initiated}, %SettleExternalPayment{} = cmd) do
    %ExternalPaymentSettled{
      payment_id: cmd.payment_id,
      org_id: cmd.org_id,
      external_reference: cmd.external_reference,
      settled_at: cmd.settled_at
    }
  end

  def execute(%__MODULE__{status: :initiated}, %FailExternalPayment{} = cmd) do
    %ExternalPaymentFailed{
      payment_id: cmd.payment_id,
      org_id: cmd.org_id,
      external_reference: cmd.external_reference,
      reason: cmd.reason,
      failed_at: cmd.failed_at
    }
  end

  # Idempotency
  def execute(%__MODULE__{}, _cmd), do: []

  # --- State Transitions ---

  def apply(%__MODULE__{} = state, %ExternalPaymentInitiated{} = event) do
    %__MODULE__{
      state
      | id: event.payment_id,
        org_id: event.org_id,
        transfer_id: event.transfer_id,
        amount: event.amount,
        currency: event.currency,
        status: :initiated
    }
  end

  def apply(%__MODULE__{} = state, %ExternalPaymentSettled{} = event) do
    %__MODULE__{state | status: :settled, external_reference: event.external_reference}
  end

  def apply(%__MODULE__{} = state, %ExternalPaymentFailed{} = _event) do
    %__MODULE__{state | status: :failed}
  end
end
