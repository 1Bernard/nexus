defmodule Nexus.ERP do
  @moduledoc """
  The ERP context. Handles invoice ingestion, status tracking, and bank statement uploads.
  """
  import Ecto.Query
  alias Nexus.Repo
  alias Nexus.Treasury.Projections.PolicyAuditLog
  alias Nexus.Reporting.Projections.AuditLog
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

    # Fetch Invoices
    invoices_query =
      if org_id == :all do
        InvoiceQuery.base()
      else
        InvoiceQuery.base()
        |> InvoiceQuery.for_org(org_id)
      end

    invoices =
      invoices_query
      |> InvoiceQuery.newest_first()
      |> Repo.all()
      |> Enum.map(fn inv ->
        %{
          id: inv.id,
          icon: activity_icon(inv.status),
          color: activity_color(inv.status),
          title: activity_title(inv),
          subtitle: "SAP BELNR: #{inv.sap_document_number}",
          created_at: inv.created_at,
          time: format_time(inv.created_at)
        }
      end)

    # Fetch Policy Audits
    policy_query =
      if org_id == :all do
        PolicyAuditLog
      else
        from(p in PolicyAuditLog, where: p.org_id == ^org_id)
      end

    audits =
      policy_query
      |> order_by(desc: :changed_at)
      |> Repo.all()
      |> Enum.map(fn log ->
        %{
          id: log.id,
          icon: "hero-shield-check",
          color: "emerald",
          title: "Policy: Mode changed to #{log.mode}",
          subtitle: "Actor: #{log.actor_email}",
          created_at: log.changed_at,
          time: format_time(log.changed_at)
        }
      end)

    # Fetch Platform Audit Logs
    audit_logs =
      AuditLog
      |> (fn query ->
            if org_id == :all do
              query
            else
              from(a in query, where: a.org_id == ^org_id)
            end
          end).()
      |> order_by(desc: :recorded_at)
      |> Repo.all()
      |> Enum.map(fn log ->
        %{
          id: log.id,
          icon: audit_icon(log.event_type),
          color: "indigo",
          title: render_audit_title(log),
          subtitle:
            "By #{log.actor_email} • #{Calendar.strftime(log.recorded_at, "%b %d, %H:%M:%S")}",
          created_at: log.recorded_at,
          time: format_time(log.recorded_at)
        }
      end)

    # Merge and Sort
    (invoices ++ audits ++ audit_logs)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    |> Enum.drop(offset)
    |> Enum.take(limit)
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

  defp audit_icon("tenant_provisioned"), do: "hero-plus-circle"
  defp audit_icon("tenant_suspended"), do: "hero-pause-circle"
  defp audit_icon("tenant_module_toggled"), do: "hero-adjustments-horizontal"
  defp audit_icon(_), do: "hero-finger-print"

  defp render_audit_title(%{event_type: "tenant_provisioned", tenant_name: name}),
    do: "Provisioned new tenant: #{name || "Unknown Tenant"}"

  defp render_audit_title(%{event_type: "tenant_suspended", tenant_name: name}),
    do: "Suspended tenant: #{name || "Unknown Tenant"}"

  defp render_audit_title(%{
         event_type: "tenant_module_toggled",
         details: %{"module_name" => mod, "enabled" => true}
       }),
       do: "Enabled feature: #{mod}"

  defp render_audit_title(%{
         event_type: "tenant_module_toggled",
         details: %{"module_name" => mod, "enabled" => false}
       }),
       do: "Disabled feature: #{mod}"

  defp render_audit_title(_), do: "System Level Action"

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

  @doc """
  Checks if a statement with the same content hash already exists for an organization.
  """
  def statement_exists_by_hash?(org_id, hash) do
    from(s in Statement,
      where: s.org_id == ^org_id and s.content_hash == ^hash,
      select: count(s.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  @doc """
  Checks if a statement with the same filename already exists for an organization.
  """
  def statement_exists_by_filename?(org_id, filename) do
    from(s in Statement,
      where: s.org_id == ^org_id and s.filename == ^filename,
      select: count(s.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end
end
