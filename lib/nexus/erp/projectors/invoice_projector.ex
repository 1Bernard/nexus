defmodule Nexus.ERP.Projectors.InvoiceProjector do
  @moduledoc """
  Listens for InvoiceIngested and InvoiceRejected events and writes
  the invoice read model to the erp_invoices table.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "ERP.InvoiceProjector",
    consistency: :strong

  alias Nexus.ERP.Events.{InvoiceIngested, InvoiceRejected, InvoiceMatched}
  alias Nexus.ERP.Projections.Invoice
  import Ecto.Query

  project(%InvoiceIngested{} = event, _metadata, fn multi ->
    case Ecto.UUID.cast(event.invoice_id) do
      {:ok, _id} ->
        # Idempotent insert: if it already exists, do nothing
        Ecto.Multi.insert(
          multi,
          :invoice,
          %Invoice{
            id: event.invoice_id,
            org_id: event.org_id,
            entity_id: event.entity_id,
            currency: event.currency,
            amount: coerce_to_string(event.amount),
            subsidiary: event.subsidiary,
            line_items: event.line_items || [],
            sap_document_number: event.sap_document_number,
            sap_status: event.sap_status,
            status: "ingested",
            due_date: parse_due_date(event.due_date),
            created_at: Nexus.Schema.parse_datetime(event.ingested_at),
            updated_at: Nexus.Schema.parse_datetime(event.ingested_at)
          },
          on_conflict: :nothing,
          conflict_target: :id
        )

      :error ->
        multi
    end
  end)

  project(%InvoiceMatched{} = event, _metadata, fn multi ->
    query = from(i in Invoice, where: i.id == ^event.invoice_id)

    Ecto.Multi.update_all(multi, :match_invoice, query,
      set: [status: "matched", updated_at: DateTime.utc_now()]
    )
  end)

  project(%InvoiceRejected{} = _event, _metadata, fn multi ->
    # Rejected payload. In production, this might route to an audit log or dead letter queue table.
    multi
  end)

  defp parse_due_date(nil), do: nil

  defp parse_due_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        case DateTime.new(date, ~T[00:00:00], "Etc/UTC") do
          {:ok, dt} -> %{dt | microsecond: {0, 6}}
          _ -> Nexus.Schema.parse_datetime(date_str)
        end

      _ ->
        Nexus.Schema.parse_datetime(date_str)
    end
  end

  defp parse_due_date(other), do: Nexus.Schema.parse_datetime(other)

  defp coerce_to_string(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp coerce_to_string(val) when is_binary(val), do: val

  defp coerce_to_string(val) when is_number(val),
    do: Decimal.from_float(val * 1.0) |> Decimal.to_string(:normal)

  defp coerce_to_string(_), do: "0.00"
end
