defmodule Nexus.Treasury.Projectors.LiquidityProjector do
  @moduledoc """
  Listens for TransferExecuted events and updates the global cash
  position (liquidity) for each currency within an organization.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.LiquidityProjector"

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
    # Generate a deterministic UUIDv5 for the liquidity position (org_id + currency)
    # This ensures it is a valid binary_id and compliant with Rule 6.
    # DNS Namespace or custom
    namespace = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    id = Uniq.UUID.uuid5(namespace, "#{event.org_id}-#{currency}")
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
      conflict_target: [:org_id, :currency]
    )
  end

  defp parse_decimal(val), do: Nexus.Schema.parse_decimal(val)
end
