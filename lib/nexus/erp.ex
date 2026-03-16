defmodule Nexus.ERP do
  @moduledoc """
  The ERP context facade.

  Handles invoice ingestion, status tracking, and bank statement uploads.
  Delegates query orchestration to specialized query modules.
  """
  alias Nexus.Repo
  alias Nexus.ERP.Queries.{InvoiceQuery, StatementQuery, StatementLineQuery}
  alias Nexus.Treasury.Queries.PolicyAuditLogQuery
  alias Nexus.Reporting.Queries.AuditLogQuery

  alias Nexus.Types

  @type matching_stats :: %{
          matched: integer(),
          partial: integer(),
          unmatched: integer(),
          unmatched_lines: integer()
        }

  @type activity_item :: %{
          id: Types.binary_id(),
          icon: String.t(),
          color: String.t(),
          title: String.t(),
          subtitle: String.t(),
          created_at: Types.datetime(),
          time: String.t()
        }

  @doc """
  Returns payment matching statistics for an organization.
  """
  @spec get_payment_matching_stats(Types.org_id()) :: matching_stats()
  def get_payment_matching_stats(org_id) do
    %{
      matched: count_invoices_by_status(org_id, "matched"),
      partial: count_invoices_by_status(org_id, "partial"),
      unmatched: count_invoices_by_status(org_id, "unmatched"),
      unmatched_lines: count_lines_by_status(org_id, "unmatched")
    }
  end

  defp count_lines_by_status(org_id, status) do
    StatementLineQuery.base()
    |> StatementLineQuery.for_org(org_id)
    |> StatementLineQuery.with_status(status)
    |> StatementLineQuery.count()
    |> Repo.one() || 0
  end

  defp count_invoices_by_status(org_id, status) do
    query =
      if org_id == :all do
        InvoiceQuery.base()
      else
        InvoiceQuery.base()
        |> InvoiceQuery.for_org(org_id)
      end

    query
    |> InvoiceQuery.with_status(status)
    |> InvoiceQuery.count()
    |> Repo.one() || 0
  end

  @doc """
  Calculates the total exposure amount for a subsidiary and currency.
  """
  @spec get_total_exposure(Types.org_id(), String.t(), Types.currency()) :: Types.money()
  def get_total_exposure(org_id, subsidiary, currency) do
    query =
      if org_id == :all do
        InvoiceQuery.base()
      else
        InvoiceQuery.base()
        |> InvoiceQuery.for_org(org_id)
      end

    query
    |> InvoiceQuery.for_subsidiary(subsidiary)
    |> InvoiceQuery.with_currency(currency)
    |> InvoiceQuery.sum_amount()
    |> Repo.one() || Decimal.new(0)
  end

  @doc """
  Lists activities related to invoices with support for pagination.
  """
  @spec list_activity(Types.org_id(), Keyword.t()) :: [activity_item()]
  def list_activity(org_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    invoices =
      InvoiceQuery.activity_query(org_id)
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

    audits =
      PolicyAuditLogQuery.list_for_org(org_id)
      |> Repo.all()
      |> Enum.map(fn log ->
        %{
          id: log.id,
          icon: "hero-shield-check",
          color: "emerald",
          title: "Policy: Mode changed to #{log.mode} (#{log.org_name || "Nexus"})",
          subtitle: "Actor: #{log.actor_email}",
          created_at: log.changed_at,
          time: format_time(log.changed_at)
        }
      end)

    audit_logs =
      AuditLogQuery.newest_for_org_query(org_id, 20)
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
  @spec list_recent_activity(Types.org_id()) :: [activity_item()]
  def list_recent_activity(org_id) do
    list_activity(org_id, limit: 5)
  end

  defp format_time(dt) do
    diff = DateTime.diff(Nexus.Schema.utc_now(), dt)

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
  @spec list_statements(Types.org_id(), String.t(), String.t()) :: [Projections.Statement.t()]
  def list_statements(org_id, query \\ "", date \\ "") do
    StatementQuery.list_query(org_id, query, date)
    |> Repo.all()
  end

  @doc """
  Returns the raw content of a bank statement.
  """
  @spec get_statement_content(Types.binary_id()) :: String.t() | nil
  def get_statement_content(id) do
    StatementQuery.content_query(id)
    |> Repo.one()
  end

  @doc """
  Lists all parsed transaction lines for a given statement.
  """
  @spec list_statement_lines(Types.binary_id()) :: [Projections.StatementLine.t()]
  def list_statement_lines(statement_id) do
    StatementLineQuery.for_statement_query(statement_id)
    |> StatementLineQuery.oldest_first()
    |> Repo.all()
  end

  @doc """
  Checks if a statement with the same content hash already exists for an organization.
  """
  @spec statement_exists_by_hash?(Types.org_id(), String.t()) :: boolean()
  def statement_exists_by_hash?(org_id, hash) do
    StatementQuery.base()
    |> StatementQuery.for_org(org_id)
    |> StatementQuery.with_hash(hash)
    |> StatementQuery.count()
    |> Repo.one()
    |> Kernel.>(0)
  end

  @doc """
  Checks if a statement with the same filename already exists for an organization.
  """
  @spec statement_exists_by_filename?(Types.org_id(), String.t()) :: boolean()
  def statement_exists_by_filename?(org_id, filename) do
    StatementQuery.base()
    |> StatementQuery.for_org(org_id)
    |> StatementQuery.with_filename(filename)
    |> StatementQuery.count()
    |> Repo.one()
    |> Kernel.>(0)
  end
end
