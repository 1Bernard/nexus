defmodule Nexus.ERP.Projectors.InvoiceProjector do
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "ERP.InvoiceProjector",
    consistency: :strong

  alias Nexus.ERP.Events.{InvoiceIngested, InvoiceRejected}
  alias Nexus.ERP.Projections.Invoice

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
            amount: to_string(event.amount),
            subsidiary: event.subsidiary,
            line_items: event.line_items || [],
            sap_document_number: event.sap_document_number,
            status: "ingested",
            created_at: parse_date(event.ingested_at) || DateTime.utc_now(),
            updated_at: parse_date(event.ingested_at) || DateTime.utc_now()
          },
          on_conflict: :nothing,
          conflict_target: :id
        )

      :error ->
        multi
    end
  end)

  project(%InvoiceRejected{} = _event, _metadata, fn multi ->
    # Rejected payload. In production, this might route to an audit log or dead letter queue table.
    multi
  end)

  @impl Commanded.Projections.Ecto
  def after_update(event, _metadata, _changes) do
    case event do
      %InvoiceIngested{} ->
        Phoenix.PubSub.broadcast(
          Nexus.PubSub,
          "erp_invoices:#{event.org_id}",
          {:invoice_ingested, event.invoice_id}
        )

      _ ->
        :ok
    end

    :ok
  end

  defp parse_date(nil), do: nil
  defp parse_date(%DateTime{} = dt), do: dt

  defp parse_date(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
end
