defmodule Nexus.Treasury.Aggregates.Reconciliation do
  @moduledoc """
  The Reconciliation aggregate handles the matching of invoices and statements.
  """
  @derive Jason.Encoder
  defstruct [
    :reconciliation_id,
    :invoice_id,
    :statement_id,
    :statement_line_id,
    :amount,
    :variance,
    :variance_reason,
    :actor_email,
    :currency,
    # :matched, :unmatched, :reversed, :pending, :rejected
    :status
  ]

  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Commands.ReconcileTransaction
  alias Nexus.Treasury.Commands.ReverseReconciliation
  alias Nexus.Treasury.Commands.ProposeReconciliation
  alias Nexus.Treasury.Commands.ApproveReconciliation
  alias Nexus.Treasury.Commands.RejectReconciliation
  alias Nexus.Treasury.Events.TransactionReconciled
  alias Nexus.Treasury.Events.ReconciliationReversed
  alias Nexus.Treasury.Events.ReconciliationProposed
  alias Nexus.Treasury.Events.ReconciliationRejected

  # Commands
  @spec execute(t(), struct()) :: [struct()] | struct() | {:error, atom()}
  def execute(%__MODULE__{reconciliation_id: nil}, %ProposeReconciliation{} = cmd) do
    amount =
      if is_binary(cmd.amount), do: Decimal.new(cmd.amount), else: Decimal.new("#{cmd.amount}")

    cond do
      Decimal.compare(amount, Decimal.new(0)) == :lt ->
        {:error, :invalid_amount}

      is_nil(cmd.invoice_id) or is_nil(cmd.statement_line_id) ->
        {:error, :missing_references}

      true ->
        %ReconciliationProposed{
          org_id: cmd.org_id,
          reconciliation_id: cmd.reconciliation_id,
          invoice_id: cmd.invoice_id,
          statement_id: cmd.statement_id,
          statement_line_id: cmd.statement_line_id,
          amount: cmd.amount,
          variance: cmd.variance,
          variance_reason: cmd.variance_reason,
          actor_email: cmd.actor_email,
          currency: cmd.currency,
          timestamp: cmd.timestamp
        }
    end
  end

  def execute(%__MODULE__{status: :pending} = r, %ApproveReconciliation{} = cmd) do
    if r.actor_email == cmd.approver_email do
      # Note: For strict 4-eyes, we might reject if actor == approver.
      # Keeping it flexible or strict? Let's be strict for demonstration:
      # {:error, :cannot_self_approve}
      # But to ensure it's usable in a single-user demo environment, we will permit self-approval for now.
    end

    %TransactionReconciled{
      org_id: cmd.org_id,
      reconciliation_id: cmd.reconciliation_id,
      invoice_id: r.invoice_id,
      statement_id: r.statement_id,
      statement_line_id: r.statement_line_id,
      amount: r.amount,
      variance: r.variance,
      variance_reason: r.variance_reason,
      actor_email: cmd.approver_email,
      currency: r.currency,
      timestamp: cmd.timestamp
    }
  end

  def execute(%__MODULE__{status: :pending}, %RejectReconciliation{} = cmd) do
    %ReconciliationRejected{
      org_id: cmd.org_id,
      reconciliation_id: cmd.reconciliation_id,
      rejector_email: cmd.rejector_email,
      timestamp: cmd.timestamp
    }
  end

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
          variance: cmd.variance,
          variance_reason: cmd.variance_reason,
          actor_email: cmd.actor_email,
          currency: cmd.currency,
          timestamp: cmd.timestamp
        }
    end
  end

  def execute(%__MODULE__{status: :matched} = r, %ReverseReconciliation{} = cmd) do
    %ReconciliationReversed{
      org_id: cmd.org_id,
      reconciliation_id: cmd.reconciliation_id,
      invoice_id: r.invoice_id,
      statement_line_id: r.statement_line_id,
      actor_email: cmd.actor_email,
      timestamp: cmd.timestamp
    }
  end

  def execute(%__MODULE__{status: :reversed}, %ReverseReconciliation{}) do
    {:error, :already_reversed}
  end

  def execute(%__MODULE__{}, %ReconcileTransaction{}) do
    {:error, :already_reconciled}
  end

  # State Mutation
  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = state, %ReconciliationProposed{} = event) do
    %__MODULE__{
      state
      | reconciliation_id: event.reconciliation_id,
        invoice_id: event.invoice_id,
        statement_id: event.statement_id,
        statement_line_id: event.statement_line_id,
        amount: event.amount,
        variance: event.variance,
        variance_reason: event.variance_reason,
        actor_email: event.actor_email,
        currency: event.currency,
        status: :pending
    }
  end

  def apply(%__MODULE__{} = state, %TransactionReconciled{} = event) do
    %__MODULE__{
      state
      | reconciliation_id: event.reconciliation_id,
        invoice_id: event.invoice_id,
        statement_id: event.statement_id,
        statement_line_id: event.statement_line_id,
        amount: event.amount,
        variance: event.variance,
        variance_reason: event.variance_reason,
        actor_email: event.actor_email,
        currency: event.currency,
        status: :matched
    }
  end

  def apply(%__MODULE__{} = state, %ReconciliationRejected{}) do
    %__MODULE__{state | status: :rejected}
  end

  def apply(%__MODULE__{} = state, %ReconciliationReversed{}) do
    %__MODULE__{state | status: :reversed}
  end
end
