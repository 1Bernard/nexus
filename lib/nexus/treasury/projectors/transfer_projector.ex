defmodule Nexus.Treasury.Projectors.TransferProjector do
  @moduledoc """
  Projector for the Transfer aggregate.
  Updates the `treasury_transfers` read model.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.TransferProjector"

  import Ecto.Query
  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}
  alias Nexus.Treasury.Projections.Transfer
  alias Nexus.Schema

  project(%TransferInitiated{} = event, _metadata, fn multi ->
    type = determine_type(event.user_id, event.recipient_data)

    Ecto.Multi.insert(multi, :transfer, %Transfer{
      id: event.transfer_id,
      org_id: event.org_id,
      user_id: event.user_id,
      from_currency: event.from_currency,
      to_currency: event.to_currency,
      amount: Schema.parse_decimal(event.amount),
      status: event.status,
      type: type,
      recipient_data: event.recipient_data
    })
  end)

  project(%TransferAuthorized{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :transfer, query(event.transfer_id, event.org_id),
      set: [status: "authorized"]
    )
  end)

  project(%TransferExecuted{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :transfer, query(event.transfer_id, event.org_id),
      set: [status: "executed", executed_at: event.executed_at]
    )
  end)

  defp query(id, org_id) do
    from(t in Transfer, where: t.id == ^id and t.org_id == ^org_id)
  end

  defp determine_type("system-rebalance", _), do: "rebalance"
  defp determine_type(_, %{"type" => "vault"}), do: "internal"
  defp determine_type(_, %{type: "vault"}), do: "internal"
  defp determine_type(_, _), do: "external"
end
