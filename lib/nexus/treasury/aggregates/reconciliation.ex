defmodule Nexus.Treasury.Aggregates.Reconciliation do
  @moduledoc """
  The Reconciliation aggregate handles the matching of invoices and statements.
  """
  defstruct [
    :reconciliation_id,
    # :matched, :unmatched
    :status
  ]

  alias Nexus.Treasury.Commands.ReconcileTransaction
  alias Nexus.Treasury.Events.TransactionReconciled

  # Commands
  def execute(%__MODULE__{reconciliation_id: nil}, %ReconcileTransaction{} = cmd) do
    amount =
      if is_binary(cmd.amount), do: Decimal.new(cmd.amount), else: Decimal.new("#{cmd.amount}")

    cond do
      Decimal.compare(amount, Decimal.new(0)) == :lt ->
        {:error, :invalid_amount}

      is_nil(cmd.invoice_id) or is_nil(cmd.statement_line_id) ->
        {:error, :missing_references}

      true ->
        %TransactionReconciled{
          org_id: cmd.org_id,
          reconciliation_id: cmd.reconciliation_id,
          invoice_id: cmd.invoice_id,
          statement_id: cmd.statement_id,
          statement_line_id: cmd.statement_line_id,
          amount: cmd.amount,
          currency: cmd.currency,
          timestamp: DateTime.utc_now()
        }
    end
  end

  def execute(%__MODULE__{}, %ReconcileTransaction{}) do
    {:error, :already_reconciled}
  end

  # State Mutation
  def apply(%__MODULE__{} = state, %TransactionReconciled{} = event) do
    %__MODULE__{
      state
      | reconciliation_id: event.reconciliation_id,
        status: :matched
    }
  end
end
