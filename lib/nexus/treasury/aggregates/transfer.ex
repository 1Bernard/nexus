defmodule Nexus.Treasury.Aggregates.Transfer do
  @moduledoc """
  Aggregate to manage Fund Transfers and their authorization states.
  """
  defstruct [:id, :org_id, :status, :amount]

  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Treasury.Events.TransferRequested

  # --- Constants ---
  @default_limit 1_000_000

  # --- Command Handlers ---

  def execute(%__MODULE__{id: nil}, %RequestTransfer{} = cmd) do
    amount = parse_decimal(cmd.amount)
    # Use the dynamic threshold from the command, or fall back to default
    threshold = parse_decimal(cmd.threshold || @default_limit)

    if Decimal.gt?(amount, threshold) do
      {:error, :step_up_required}
    else
      %TransferRequested{
        transfer_id: cmd.transfer_id,
        org_id: cmd.org_id,
        user_id: cmd.user_id,
        from_currency: cmd.from_currency,
        to_currency: cmd.to_currency,
        amount: cmd.amount,
        requested_at: DateTime.utc_now()
      }
    end
  end

  # --- State Transitions ---

  def apply(%__MODULE__{} = state, %TransferRequested{} = ev) do
    %__MODULE__{
      state
      | id: ev.transfer_id,
        org_id: ev.org_id,
        amount: ev.amount,
        status: :requested
    }
  end

  # --- Private Helpers ---

  defp parse_decimal(val) when is_struct(val, Decimal), do: val
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
end
