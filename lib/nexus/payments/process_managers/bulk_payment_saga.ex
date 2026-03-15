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
  alias Nexus.Treasury.Events.TransferInitiated
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Payments.Commands.FinalizeBulkPayment
  alias Nexus.ERP.Commands.MatchInvoice

  # 1. Start the saga when bulk payment is initiated
  def interested?(%BulkPaymentInitiated{bulk_payment_id: id}), do: {:start, id}
  # 2. Track progress for each individual transfer initiated in the context of this bulk
  def interested?(%TransferInitiated{transfer_id: _id} = event) do
    # We need a way to correlate individual transfers back to the bulk batch.
    # In a real system, we'd use correlation IDs or a field in the event.
    # For this POC, let's look for a `bulk_payment_id` field in the event.
    case Map.get(event, :bulk_payment_id) do
      nil -> false
      bulk_id -> {:continue, bulk_id}
    end
  end

  def interested?(_event), do: false

  # --- Command Dispatch ---

  def handle(%__MODULE__{} = _saga, %BulkPaymentInitiated{} = event) do
    # For each payment instruction, dispatch a RequestTransfer command.
    # We use a deterministic transfer_id based on bulk_payment_id and index to ensure
    # that retries of this handle function result in the same IDs.
    event.payments
    |> Enum.with_index()
    |> Enum.flat_map(fn {p, index} ->
      # Generate a stable UUID v5 using the bulk_payment_id as a "namespace"
      # This ensures that even on Saga restart/retry, the same transfer_id is generated.
      transfer_id = generate_deterministic_id(event.bulk_payment_id, index)

      transfer_cmd = %RequestTransfer{
        transfer_id: transfer_id,
        org_id: event.org_id,
        user_id: event.user_id,
        from_currency: p.currency,
        to_currency: "EUR",
        amount: p.amount,
        threshold: Decimal.new(1_000_000),
        bulk_payment_id: event.bulk_payment_id,
        requested_at: Nexus.Schema.utc_now()
      }

      invoice_id = Map.get(p, :invoice_id) || Map.get(p, "invoice_id")

      if invoice_id do
        match_cmd = %MatchInvoice{
          invoice_id: invoice_id,
          org_id: event.org_id,
          matched_type: "bulk_payment",
          matched_id: event.bulk_payment_id,
          matched_at: event.initiated_at
        }

        [transfer_cmd, match_cmd]
      else
        [transfer_cmd]
      end
    end)
  end

  def handle(
        %__MODULE__{processed_items: processed, total_items: total} = saga,
        %TransferInitiated{} = _ev
      ) do
    if processed + 1 >= total do
      %FinalizeBulkPayment{
        bulk_payment_id: saga.bulk_payment_id,
        org_id: saga.org_id,
        completed_at: Nexus.Schema.utc_now()
      }
    else
      []
    end
  end

  defp generate_deterministic_id(bulk_id, index) do
    # Convert bulk_id to binary if it's a string, then hash with index
    seed = "#{bulk_id}-#{index}"
    # Use HMAC or just hash to derive a stable UUID-like binary
    hash = :crypto.hash(:sha256, seed)

    <<part1::binary-size(4), part2::binary-size(2), part3::binary-size(2), part4::binary-size(2),
      part5::binary-size(6), _rest::binary>> = hash

    # Construct a valid UUID string from the hash parts
    # (Simplified UUID v4-ish construction for stability)
    "#{Base.encode16(part1)}-#{Base.encode16(part2)}-#{Base.encode16(part3)}-#{Base.encode16(part4)}-#{Base.encode16(part5)}"
    |> String.downcase()
  end

  # --- State Mutators ---

  def apply(%__MODULE__{} = saga, %BulkPaymentInitiated{} = event) do
    %__MODULE__{
      saga
      | bulk_payment_id: event.bulk_payment_id,
        org_id: event.org_id,
        total_items: event.count,
        processed_items: 0
    }
  end

  def apply(%__MODULE__{processed_items: processed} = saga, %TransferInitiated{} = _event) do
    %__MODULE__{saga | processed_items: processed + 1}
  end
end
