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
  Lists activities related to invoices with support for pagination.
  """
  def list_activity(org_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    InvoiceQuery.base()
    |> InvoiceQuery.for_org(org_id)
    |> InvoiceQuery.newest_first()
    |> InvoiceQuery.limit_results(limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(fn invoice ->
      %{
        id: invoice.id,
        icon: activity_icon(invoice.status),
        color: activity_color(invoice.status),
        title: activity_title(invoice),
        subtitle: "SAP: #{invoice.sap_document_number}",
        # In a real app we'd use invoice.created_at
        time: format_time(invoice.created_at)
      }
    end)
  end

  @doc """
  Lists the 5 most recent activities related to invoices.
  """
  def list_recent_activity(org_id) do
    list_activity(org_id, limit: 5)
  end

  defp format_time(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> Calendar.strftime(dt, "%b %d")
    end
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
  Supports filtering by filename and date.
  """
  def list_statements(org_id, query \\ "", date \\ "") do
    from(s in Statement,
      where: s.org_id == ^org_id,
      order_by: [desc: s.uploaded_at]
    )
    |> filter_by_filename(query)
    |> filter_by_date(date)
    |> Repo.all()
  end

  defp filter_by_filename(q, ""), do: q

  defp filter_by_filename(q, query) do
    from(s in q, where: ilike(s.filename, ^"%#{query}%"))
  end

  defp filter_by_date(q, ""), do: q

  defp filter_by_date(q, date) do
    # Simple date string prefix match for the demo
    from(s in q, where: fragment("?::text", s.uploaded_at) |> ilike(^"#{date}%"))
  end

  @doc """
  Returns the raw content of a bank statement.
  """
  def get_statement_content(id) do
    from(s in Statement, where: s.id == ^id, select: s.raw_content)
    |> Repo.one()
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
