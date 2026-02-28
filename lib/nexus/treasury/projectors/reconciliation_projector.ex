defmodule Nexus.Treasury.Projectors.ReconciliationProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ReconciliationProjector",
    consistency: :strong

  alias Nexus.Treasury.Events.TransactionReconciled
  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.ERP.Projections.{Invoice, StatementLine}

  project(%TransactionReconciled{} = event, metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(:reconciliation, %Reconciliation{
      reconciliation_id: event.reconciliation_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      statement_id: event.statement_id,
      statement_line_id: event.statement_line_id,
      amount: Decimal.new(event.amount),
      currency: event.currency,
      status: :matched,
      matched_at: to_datetime(event.timestamp || metadata.created_at)
    })
    |> Ecto.Multi.update_all(
      :update_invoice_status,
      from(i in Invoice, where: i.id == ^event.invoice_id),
      set: [status: "matched"]
    )
    |> Ecto.Multi.update_all(
      :update_line_status,
      from(l in StatementLine, where: l.id == ^event.statement_line_id),
      set: [status: "matched"]
    )
  end)

  defp to_datetime(%DateTime{} = dt), do: dt

  defp to_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp to_datetime(_), do: DateTime.utc_now()
end
