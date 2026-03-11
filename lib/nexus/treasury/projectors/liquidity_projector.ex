defmodule Nexus.Treasury.Projectors.LiquidityProjector do
  @moduledoc """
  Listens for TransferExecuted events and updates the global cash
  position (liquidity) for each currency within an organization.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.LiquidityProjector",
    consistency: :strong

  import Ecto.Query
  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Treasury.Projections.LiquidityPosition

  project(%TransferExecuted{} = event, _metadata, fn multi ->
    if event.amount && event.from_currency && event.to_currency do
      amount = parse_decimal(event.amount)

      multi
      |> update_balance(event, event.from_currency, Decimal.negate(amount), :debit)
      |> update_balance(event, event.to_currency, amount, :credit)
    else
      multi
    end
  end)

  defp update_balance(multi, event, currency, delta, side) do
    id = "#{event.org_id}-#{currency}"
    # Use unique name per transfer, currency, AND side
    # This prevents collisions even when from_currency == to_currency
    op_name = {:liquidity_position, event.transfer_id, currency, side}

    Ecto.Multi.insert(
      multi,
      op_name,
      %LiquidityPosition{
        id: id,
        org_id: event.org_id,
        currency: currency,
        amount: delta
      },
      on_conflict: [set: [amount: dynamic([p], p.amount + ^delta)]],
      conflict_target: [:id]
    )
  end

  defp parse_decimal(nil), do: Decimal.new("0")
  defp parse_decimal(val) when is_struct(val, Decimal), do: val
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
end
