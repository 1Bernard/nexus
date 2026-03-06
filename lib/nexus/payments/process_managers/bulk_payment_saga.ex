defmodule Nexus.Payments.ProcessManagers.BulkPaymentSaga do
  @moduledoc """
  Saga to orchestrate Bulk Payment processing into individual Treasury transfers.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "BulkPaymentSaga"

  @derive Jason.Encoder
  defstruct [:bulk_payment_id, :org_id, :total_items, :processed_items]

  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Treasury.Events.TransferRequested
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Payments.Commands.FinalizeBulkPayment

  # 1. Start the saga when bulk payment is initiated
  def interested?(%BulkPaymentInitiated{bulk_payment_id: id}), do: {:start, id}
  # 2. Track progress for each individual transfer requested in the context of this bulk
  # Note: TransferRequested needs matching bulk_payment_id in metadata or event fields.
  # For now, let's assume we pass metadata or extend TransferRequested.
  def interested?(%TransferRequested{transfer_id: _id} = ev) do
    # We need a way to correlate individual transfers back to the bulk batch.
    # In a real system, we'd use correlation IDs or a field in the event.
    # For this POC, let's look for a `bulk_payment_id` field in the event.
    case Map.get(ev, :bulk_payment_id) do
      nil -> false
      bulk_id -> {:continue, bulk_id}
    end
  end

  def interested?(_ev), do: false

  # --- Command Dispatch ---

  def handle(%__MODULE__{} = _saga, %BulkPaymentInitiated{} = ev) do
    # For each payment instruction, dispatch a RequestTransfer command.
    # We add the bulk_payment_id to the command so the resulting event can be correlated.
    Enum.map(ev.payments, fn p ->
      %RequestTransfer{
        transfer_id: Uniq.UUID.uuid7(),
        org_id: ev.org_id,
        user_id: ev.user_id,
        from_currency: p.currency,
        # Default target for now
        to_currency: "EUR",
        amount: p.amount,
        # Default threshold
        threshold: Decimal.new(1_000_000),
        # Correlation ID for bulk batches
        bulk_payment_id: ev.bulk_payment_id,
        requested_at: DateTime.utc_now()
      }
    end)
  end

  def handle(
        %__MODULE__{processed_items: processed, total_items: total} = saga,
        %TransferRequested{} = _ev
      ) do
    if processed + 1 >= total do
      %FinalizeBulkPayment{
        bulk_payment_id: saga.bulk_payment_id,
        org_id: saga.org_id,
        completed_at: DateTime.utc_now()
      }
    else
      []
    end
  end

  # --- State Mutators ---

  def apply(%__MODULE__{} = saga, %BulkPaymentInitiated{} = ev) do
    %__MODULE__{
      saga
      | bulk_payment_id: ev.bulk_payment_id,
        org_id: ev.org_id,
        total_items: ev.count,
        processed_items: 0
    }
  end

  def apply(%__MODULE__{processed_items: processed} = saga, %TransferRequested{} = _ev) do
    %__MODULE__{saga | processed_items: processed + 1}
  end
end
