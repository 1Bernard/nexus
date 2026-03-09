defmodule Nexus.Treasury.Projectors.LiquidityProjector do
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
      |> update_balance(event.org_id, event.from_currency, Decimal.negate(amount))
      |> update_balance(event.org_id, event.to_currency, amount)
    else
      multi
    end
  end)

  defp update_balance(multi, org_id, currency, delta) do
    id = "#{org_id}-#{currency}"

    Ecto.Multi.insert(
      multi,
      {:liquidity_position, id},
      %LiquidityPosition{
        id: id,
        org_id: org_id,
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
