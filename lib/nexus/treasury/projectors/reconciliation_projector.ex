defmodule Nexus.Treasury.Projectors.ReconciliationProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.ReconciliationProjector",
    consistency: :strong

  alias Nexus.Treasury.Events.{
    TransactionReconciled,
    ReconciliationReversed,
    ReconciliationProposed,
    ReconciliationRejected
  }

  alias Nexus.Treasury.Projections.Reconciliation
  alias Nexus.ERP.Projections.{Invoice, StatementLine}
  import Ecto.Query

  project(%ReconciliationProposed{} = event, metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(:reconciliation, %Reconciliation{
      reconciliation_id: event.reconciliation_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      statement_id: event.statement_id,
      statement_line_id: event.statement_line_id,
      amount: Decimal.new(event.amount),
      variance: if(event.variance, do: Decimal.new(event.variance), else: Decimal.new("0.00")),
      variance_reason: event.variance_reason,
      actor_email: event.actor_email,
      currency: event.currency,
      status: :pending,
      matched_at: to_datetime(event.timestamp || metadata.created_at)
    })
    |> Ecto.Multi.update_all(
      :update_invoice_status,
      from(i in Invoice, where: i.id == ^event.invoice_id),
      set: [status: "pending"]
    )
    |> Ecto.Multi.update_all(
      :update_line_status,
      from(l in StatementLine, where: l.id == ^event.statement_line_id),
      set: [status: "pending"]
    )
  end)

  project(%TransactionReconciled{} = event, metadata, fn multi ->
    record = %Reconciliation{
      reconciliation_id: event.reconciliation_id,
      org_id: event.org_id,
      invoice_id: event.invoice_id,
      statement_id: event.statement_id,
      statement_line_id: event.statement_line_id,
      amount: Decimal.new(event.amount),
      variance: if(event.variance, do: Decimal.new(event.variance), else: Decimal.new("0.00")),
      variance_reason: event.variance_reason,
      actor_email: event.actor_email,
      currency: event.currency,
      status: :matched,
      matched_at: to_datetime(event.timestamp || metadata.created_at)
    }

    multi
    |> Ecto.Multi.insert(:reconciliation, record,
      conflict_target: [:reconciliation_id],
      on_conflict: [
        set: [
          status: :matched,
          actor_email: event.actor_email,
          matched_at: to_datetime(event.timestamp || metadata.created_at)
        ]
      ]
    )
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

  project(%ReconciliationRejected{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_reconciliation_status,
      from(r in Reconciliation, where: r.reconciliation_id == ^event.reconciliation_id),
      set: [status: :rejected]
    )
    |> Ecto.Multi.update_all(
      :update_invoice_status,
      from(i in Invoice,
        join: r in Reconciliation,
        on: fragment("?::text", i.id) == r.invoice_id,
        where: r.reconciliation_id == ^event.reconciliation_id
      ),
      set: [status: "ingested"]
    )
    |> Ecto.Multi.update_all(
      :update_line_status,
      from(l in StatementLine,
        join: r in Reconciliation,
        on: fragment("?::text", l.id) == r.statement_line_id,
        where: r.reconciliation_id == ^event.reconciliation_id
      ),
      set: [status: "unmatched"]
    )
  end)

  project(%ReconciliationReversed{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_reconciliation_status,
      from(r in Reconciliation, where: r.reconciliation_id == ^event.reconciliation_id),
      set: [status: :reversed]
    )
    |> Ecto.Multi.update_all(
      :update_invoice_status,
      from(i in Invoice, where: i.id == ^event.invoice_id),
      set: [status: "ingested"]
    )
    |> Ecto.Multi.update_all(
      :update_line_status,
      from(l in StatementLine, where: l.id == ^event.statement_line_id),
      set: [status: "unmatched"]
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
