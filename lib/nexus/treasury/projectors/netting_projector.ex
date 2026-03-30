defmodule Nexus.Treasury.Projectors.NettingProjector do
  @moduledoc """
  Projector for the Netting aggregate.
  Updates the `treasury_netting_cycles` and `treasury_netting_entries` read models.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.NettingProjector"

  alias Nexus.Treasury.Events.{NettingCycleInitialized, InvoiceAddedToNetting}
  alias Nexus.Treasury.Projections.{NettingCycle, NettingEntry}
  require Logger

  project(%NettingCycleInitialized{} = event, _metadata, fn multi ->
    Logger.debug("[NettingProjector] Projecting NettingCycleInitialized: #{event.netting_id}")

    attrs = %{
      id: event.netting_id,
      org_id: event.org_id,
      currency: event.currency,
      status: "active",
      period_start: event.period_start,
      period_end: event.period_end,
      total_amount: Decimal.new(0)
    }

    Ecto.Multi.insert(multi, :netting_cycle, NettingCycle.changeset(%NettingCycle{}, attrs),
      on_conflict: :nothing, conflict_target: :id)
  end)

  project(%InvoiceAddedToNetting{} = event, _metadata, fn multi ->
    attrs = %{
      id: Nexus.Schema.generate_uuidv7(),
      netting_id: event.netting_id,
      invoice_id: event.invoice_id,
      subsidiary: event.subsidiary,
      amount: event.amount,
      currency: event.currency
    }

    multi
    |> Ecto.Multi.insert(:netting_entry, NettingEntry.changeset(%NettingEntry{}, attrs),
      on_conflict: :nothing, conflict_target: [:netting_id, :invoice_id])
    |> Ecto.Multi.update_all(:update_cycle_total,
      Ecto.Query.from(c in NettingCycle, where: c.id == ^event.netting_id),
      inc: [total_amount: event.amount]
    )
  end)
end
