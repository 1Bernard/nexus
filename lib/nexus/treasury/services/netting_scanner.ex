defmodule Nexus.Treasury.Services.NettingScanner do
  @moduledoc """
  Automates the discovery and inclusion of intercompany invoices for netting.
  """
  import Ecto.Query
  require Logger

  alias Nexus.Repo
  alias Nexus.App
  alias Nexus.Treasury.Projections.NettingCycle
  alias Nexus.ERP.Projections.Invoice
  alias Nexus.Treasury.Commands.AddInvoiceToNetting

  @doc """
  Scans for eligible invoices and dispatches inclusion commands.
  Eligible invoices match the cycle's currency, date range, and are currently "ingested".
  """
  def scan(netting_id, org_id, user_id) do
    Logger.info("[NettingScanner] Starting scan for cycle: #{netting_id}")

    with %NettingCycle{} = cycle <- Repo.get(NettingCycle, netting_id),
         invoices <- fetch_eligible_invoices(cycle) do

      invoice_count = length(invoices)
      Logger.info("[NettingScanner] Found #{invoice_count} eligible invoices for #{cycle.currency}")

      invoices
      |> Enum.each(fn inv ->
        cmd = %AddInvoiceToNetting{
          netting_id: netting_id,
          org_id: org_id,
          invoice_id: inv.id,
          subsidiary: inv.subsidiary,
          amount: inv.amount,
          currency: inv.currency,
          user_id: user_id
        }

        case App.dispatch(cmd) do
          :ok -> :ok
          {:error, reason} ->
            Logger.error("[NettingScanner] Failed to add invoice #{inv.id}: #{inspect(reason)}")
        end
      end)

      # Emit the completion event manually or via the aggregate?
      # Usually, the scanner is an external trigger.
      # We could emit a domain event if we want to track this in the event store.
      # For now, we'll return the count.
      {:ok, invoice_count}
    else
      nil -> {:error, :netting_cycle_not_found}
      error -> {:error, error}
    end
  end

  defp fetch_eligible_invoices(cycle) do
    from(i in Invoice,
      where: i.org_id == ^cycle.org_id,
      where: i.currency == ^cycle.currency,
      where: i.status == "ingested",
      where: i.due_date >= ^cycle.period_start,
      where: i.due_date <= ^cycle.period_end
    )
    |> Repo.all()
  end
end
