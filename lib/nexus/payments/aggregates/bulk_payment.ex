defmodule Nexus.Payments.Aggregates.BulkPayment do
  @moduledoc """
  Aggregate to manage Bulk Payment batches.
  """
  defstruct [:id, :org_id, :status, :total_items, :processed_items]

  alias Nexus.Payments.Commands.InitiateBulkPayment
  alias Nexus.Payments.Commands.FinalizeBulkPayment
  alias Nexus.Payments.Events.BulkPaymentInitiated
  alias Nexus.Payments.Events.BulkPaymentCompleted

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %InitiateBulkPayment{} = cmd) do
    total_amount =
      Enum.reduce(cmd.payments, Decimal.new(0), fn p, acc ->
        Decimal.add(acc, p.amount)
      end)

    %BulkPaymentInitiated{
      bulk_payment_id: cmd.bulk_payment_id,
      org_id: cmd.org_id,
      user_id: cmd.user_id,
      payments: cmd.payments,
      total_amount: total_amount,
      count: length(cmd.payments),
      initiated_at: cmd.initiated_at
    }
  end

  def execute(%__MODULE__{status: status}, %FinalizeBulkPayment{} = cmd)
      when status != :completed do
    %BulkPaymentCompleted{
      bulk_payment_id: cmd.bulk_payment_id,
      org_id: cmd.org_id,
      completed_at: cmd.completed_at
    }
  end

  # Idempotency: If already completed, do nothing
  def execute(%__MODULE__{status: :completed}, %FinalizeBulkPayment{}), do: []

  def apply(%__MODULE__{} = state, %BulkPaymentInitiated{} = event) do
    %__MODULE__{
      state
      | id: event.bulk_payment_id,
        org_id: event.org_id,
        status: :initiated,
        total_items: event.count,
        processed_items: 0
    }
  end

  def apply(%__MODULE__{} = state, %BulkPaymentCompleted{} = _event) do
    %__MODULE__{state | status: :completed}
  end
end
