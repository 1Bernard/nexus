defmodule Nexus.Treasury.Aggregates.Transfer do
  @moduledoc """
  Aggregate to manage Fund Transfers and their authorization states.
  """
  @derive Jason.Encoder
  defstruct [
    :id,
    :org_id,
    :user_id,
    :from_currency,
    :to_currency,
    :amount,
    :status,
    :recipient_data
  ]

  @type t :: %__MODULE__{}

  alias Nexus.Treasury.Commands.{RequestTransfer, AuthorizeTransfer, ExecuteTransfer}
  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}

  # --- Constants ---

  # --- Command Handlers ---

  @spec execute(t(), RequestTransfer.t() | AuthorizeTransfer.t() | ExecuteTransfer.t()) ::
          Commanded.Aggregate.Multi.t() | [struct()] | struct() | {:error, atom()}
  def execute(%__MODULE__{id: nil}, %RequestTransfer{} = cmd) do
    _amount = parse_decimal(cmd.amount)
    # Use the dynamic threshold from the command, or fall back to default
    threshold = cmd.threshold || Decimal.new(1_000_000)

    status =
      if Decimal.lt?(cmd.amount, threshold) do
        "authorized"
      else
        "pending_authorization"
      end

    %TransferInitiated{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      user_id: cmd.user_id,
      from_currency: cmd.from_currency,
      to_currency: cmd.to_currency,
      amount: cmd.amount,
      status: status,
      bulk_payment_id: cmd.bulk_payment_id,
      recipient_data: cmd.recipient_data,
      requested_at: cmd.requested_at
    }
  end

  # Idempotency: If transfer already exists, do nothing
  def execute(%__MODULE__{}, %RequestTransfer{}), do: []

  def execute(%__MODULE__{status: "pending_authorization"}, %AuthorizeTransfer{} = cmd) do
    %TransferAuthorized{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      user_id: cmd.user_id,
      actor_email: cmd.actor_email,
      authorized_at: cmd.authorized_at
    }
  end

  # Idempotency: If already authorized or executed, do nothing
  def execute(%__MODULE__{status: "authorized"}, %AuthorizeTransfer{}), do: []
  def execute(%__MODULE__{status: "executed"}, %AuthorizeTransfer{}), do: []

  def execute(
        %__MODULE__{status: "authorized", recipient_data: recipient} = state,
        %ExecuteTransfer{} = cmd
      ) do
    %TransferExecuted{
      transfer_id: cmd.transfer_id,
      org_id: cmd.org_id,
      amount: state.amount,
      from_currency: state.from_currency,
      to_currency: state.to_currency,
      recipient_data: recipient,
      executed_at: cmd.executed_at
    }
  end

  # Idempotency: If already executed, do nothing
  def execute(%__MODULE__{status: "executed"}, %ExecuteTransfer{}), do: []

  # --- State Transitions ---

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = state, %TransferInitiated{} = event) do
    %__MODULE__{
      state
      | id: event.transfer_id,
        org_id: event.org_id,
        user_id: event.user_id,
        from_currency: event.from_currency,
        to_currency: event.to_currency,
        amount: event.amount,
        status: event.status,
        recipient_data: event.recipient_data
    }
  end

  def apply(%__MODULE__{} = state, %TransferAuthorized{} = _event) do
    %__MODULE__{state | status: "authorized"}
  end

  def apply(%__MODULE__{} = state, %TransferExecuted{} = _event) do
    %__MODULE__{state | status: "executed"}
  end

  # --- Private Helpers ---

  defp parse_decimal(val), do: Nexus.Schema.parse_decimal(val)
end
