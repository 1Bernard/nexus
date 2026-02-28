defmodule Nexus.ERP do
  @moduledoc """
  The ERP context. Handles invoice ingestion, status tracking, and bank statement uploads.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.ERP.Queries.InvoiceQuery
  alias Nexus.ERP.Projections.{Statement, StatementLine}

  @doc """
  Returns payment matching statistics for an organization.
  """
  def get_payment_matching_stats(org_id) do
    %{
      matched: count_invoices_by_status(org_id, "matched"),
      partial: count_invoices_by_status(org_id, "partial"),
      unmatched: count_invoices_by_status(org_id, "unmatched"),
      unmatched_lines: count_lines_by_status(org_id, "unmatched")
    }
  end

  defp count_lines_by_status(org_id, status) do
    from(l in StatementLine,
      where: l.org_id == ^org_id and l.status == ^status,
      select: count(l.id)
    )
    |> Repo.one() || 0
  end

  defp count_invoices_by_status(org_id, status) do
    InvoiceQuery.base()
    |> InvoiceQuery.for_org(org_id)
    |> InvoiceQuery.with_status(status)
    |> InvoiceQuery.count()
    |> Repo.one() || 0
  end

  @doc """
  Calculates the total exposure amount for a subsidiary and currency.
  """
  def get_total_exposure(org_id, subsidiary, currency) do
    InvoiceQuery.base()
    |> InvoiceQuery.for_org(org_id)
    |> InvoiceQuery.for_subsidiary(subsidiary)
    |> InvoiceQuery.with_currency(currency)
    |> InvoiceQuery.sum_amount()
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Lists the 5 most recent activities related to invoices.
  """
  def list_recent_activity(org_id) do
    InvoiceQuery.base()
    |> InvoiceQuery.for_org(org_id)
    |> InvoiceQuery.newest_first()
    |> InvoiceQuery.limit_results(5)
    |> Repo.all()
    |> Enum.map(fn invoice ->
      %{
        id: invoice.id,
        icon: activity_icon(invoice.status),
        color: activity_color(invoice.status),
        title: activity_title(invoice),
        subtitle: "SAP: #{invoice.sap_document_number}",
        # Simple for the demo bridge
        time: "Just now"
      }
    end)
  end

  defp activity_icon("matched"), do: "hero-check-circle"
  defp activity_icon("unmatched"), do: "hero-exclamation-triangle"
  defp activity_icon(_), do: "hero-document-text"

  defp activity_color("matched"), do: "emerald"
  defp activity_color("unmatched"), do: "amber"
  defp activity_color(_), do: "indigo"

  defp activity_title(invoice) do
    case invoice.status do
      "matched" -> "✓ Invoice Matched"
      "unmatched" -> "⚠ Action Required"
      _ -> "New Invoice Received"
    end
  end

  @doc """
  Lists all bank statements for an organisation, newest first.
  """
  def list_statements(org_id) do
    from(s in Statement,
      where: s.org_id == ^org_id,
      order_by: [desc: s.uploaded_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists all parsed transaction lines for a given statement.
  """
  def list_statement_lines(statement_id) do
    from(l in StatementLine,
      where: l.statement_id == ^statement_id,
      order_by: [asc: l.date]
    )
    |> Repo.all()
  end
end
