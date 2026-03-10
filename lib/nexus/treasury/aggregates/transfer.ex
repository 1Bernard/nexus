defmodule Nexus.Treasury.Aggregates.Transfer do
  @moduledoc """
  Aggregate to manage Fund Transfers and their authorization states.
  """
  defstruct [:id, :org_id, :status, :amount, :from_currency, :to_currency]

  alias Nexus.Treasury.Commands.{RequestTransfer, AuthorizeTransfer, ExecuteTransfer}
  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}

  # --- Constants ---
  @default_limit 1_000_000

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %RequestTransfer{} = cmd) do
    amount = parse_decimal(cmd.amount)
    # Use the dynamic threshold from the command, or fall back to default
    threshold = parse_decimal(cmd.threshold || @default_limit)

    status = if Decimal.gt?(amount, threshold), do: "pending_authorization", else: "authorized"

    %TransferInitiated{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      user_id: cmd.user_id,
      from_currency: cmd.from_currency,
      to_currency: cmd.to_currency,
      amount: cmd.amount,
      status: status,
      bulk_payment_id: cmd.bulk_payment_id,
      requested_at: cmd.requested_at
    }
  end

  # Idempotency: If transfer already exists, do nothing
  def execute(%__MODULE__{}, %RequestTransfer{}), do: []

  def execute(%__MODULE__{status: "pending_authorization"}, %AuthorizeTransfer{} = cmd) do
    %TransferAuthorized{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      actor_email: cmd.actor_email,
      authorized_at: cmd.authorized_at
    }
  end

  def execute(%__MODULE__{status: "authorized"} = state, %ExecuteTransfer{} = cmd) do
    %TransferExecuted{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      amount: state.amount,
      from_currency: state.from_currency,
      to_currency: state.to_currency,
      executed_at: cmd.executed_at
    }
  end

  # Idempotency: If already executed, do nothing
  def execute(%__MODULE__{status: "executed"}, %ExecuteTransfer{}), do: []

  # --- State Transitions ---

  def apply(%__MODULE__{} = state, %TransferInitiated{} = event) do
    %__MODULE__{
      state
      | id: event.transfer_id,
        org_id: event.org_id,
        amount: event.amount,
        from_currency: event.from_currency,
        to_currency: event.to_currency,
        status: event.status
    }
  end

  def apply(%__MODULE__{} = state, %TransferAuthorized{} = _event) do
    %__MODULE__{state | status: "authorized"}
  end

  def apply(%__MODULE__{} = state, %TransferExecuted{} = _event) do
    %__MODULE__{state | status: "executed"}
  end

  # --- Private Helpers ---

  defp parse_decimal(val) when is_struct(val, Decimal), do: val
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
end
