defmodule Nexus.Payments.ProcessManagers.PaymentExecutionSaga do
  @moduledoc """
  Saga to orchestrate the lifecycle of an individual external payment.
  Bridges Treasury Transfers with Payment Rails.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Payments.PaymentExecutionSaga"

  @derive Jason.Encoder
  defstruct [:payment_id, :transfer_id, :org_id, :status]

  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Payments.Commands.InitiateExternalPayment

  alias Nexus.Payments.Events.{
    ExternalPaymentInitiated,
    ExternalPaymentSettled,
    ExternalPaymentFailed
  }

  # 1. Start the saga when a transfer is executed in Treasury
  @spec interested?(struct()) :: {:start | :continue, binary()} | false
  def interested?(%TransferExecuted{transfer_id: id}), do: {:start, id}

  # 2. Continue for follow-up events in the Payments domain
  # We use the transfer_id as the process identifier for consistency.
  def interested?(%ExternalPaymentInitiated{transfer_id: id}), do: {:continue, id}
  def interested?(%ExternalPaymentSettled{payment_id: id}), do: {:continue, id}
  def interested?(%ExternalPaymentFailed{payment_id: id}), do: {:continue, id}

  def interested?(_event), do: false

  # --- Command Dispatch ---

  @spec handle(t(), struct()) :: [struct()] | struct() | []
  def handle(%__MODULE__{status: nil}, %TransferExecuted{} = event) do
    # Generate a unique payment_id derived from transfer_id
    payment_id = "pay-#{event.transfer_id}"

    %InitiateExternalPayment{
      payment_id: payment_id,
      org_id: event.org_id,
      transfer_id: event.transfer_id,
      amount: event.amount,
      currency: event.to_currency,
      recipient_data: event.recipient_data,
      initiated_at: Nexus.Schema.utc_now()
    }
  end

  @type t :: %__MODULE__{}
  # The saga stops once the payment is settled or failed.
  def handle(%__MODULE__{}, %ExternalPaymentSettled{} = _event), do: []
  def handle(%__MODULE__{}, %ExternalPaymentFailed{} = _event), do: []

  def handle(%__MODULE__{}, _event), do: []

  # --- State Transitions ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = saga, %TransferExecuted{} = event) do
    %__MODULE__{
      saga
      | transfer_id: event.transfer_id,
        org_id: event.org_id,
        status: :transfer_executed
    }
  end

  def apply(%__MODULE__{} = saga, %ExternalPaymentInitiated{} = event) do
    %__MODULE__{saga | payment_id: event.payment_id, status: :initiated}
  end

  def apply(%__MODULE__{} = saga, %ExternalPaymentSettled{} = _event) do
    %__MODULE__{saga | status: :settled}
  end

  def apply(%__MODULE__{} = saga, %ExternalPaymentFailed{} = _event) do
    %__MODULE__{saga | status: :failed}
  end

  # --- Stop Condition ---

  @spec stop?(t()) :: boolean()
  def stop?(%__MODULE__{status: status}), do: status in [:settled, :failed]
  def stop?(_), do: false
end
