defmodule NexusWeb.ERP.InvoiceLive do
  @moduledoc """
  LiveView for browsing, filtering, and managing ERP invoices for a tenant organisation.
  """
  use NexusWeb, :live_view

  alias Nexus.ERP.Projections.Invoice
  alias Nexus.ERP.Queries.InvoiceQuery
  alias Nexus.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    org_id = socket.assigns.current_user.org_id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "erp_invoices:#{org_id}")
      # Defer heavy aggregations to after mount
      send(self(), :load_stats)
    end

    socket =
      socket
      |> assign(page_title: "ERP Talk Back - Nexus")
      |> assign(
        org_id:
          if(Enum.member?(socket.assigns.current_user.roles, "system_admin"),
            do: :all,
            else: org_id
          )
      )
      |> assign(show_manual_modal: false)
      # Initialize with placeholders
      |> assign(total_volume: 0.0)
      |> assign(pending_count: 0)
      |> assign(total_count: 0)
      |> assign(aging_stats: %{current: 0.0, d30: 0.0, d60: 0.0, d90plus: 0.0})
      |> assign(selected_invoice: nil)
      # Setup datagrid state
      |> assign(datagrid_params: %{})
      |> assign(search: nil)
      |> assign(status_filter: "All Statuses")
      |> assign(limit: 10)
      |> assign(cursor_before: nil)
      |> assign(cursor_after: nil)
      |> load_invoices_page()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket =
      socket
      |> assign(current_path: URI.parse(uri).path)
      |> assign(datagrid_params: params)
      |> assign(search: params["search"])
      |> assign(status_filter: params["status_filter"] || "All Statuses")
      |> assign(limit: String.to_integer(params["limit"] || "10"))
      |> assign(cursor_after: params["cursor_after"])
      |> assign(cursor_before: params["cursor_before"])
      |> load_invoices_page()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-manual-modal", _, socket) do
    {:noreply, assign(socket, show_manual_modal: !socket.assigns.show_manual_modal)}
  end

  @impl true
  def handle_event("select_invoice", %{"id" => id}, socket) do
    org_id = socket.assigns.org_id
    invoice = Repo.get_by(Invoice, [id: id] ++ if(org_id == :all, do: [], else: [org_id: org_id]))
    {:noreply, assign(socket, selected_invoice: invoice)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, selected_invoice: nil)}
  end

  @impl true
  def handle_event("export-csv", _, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "Exporting #{socket.assigns.total_count} records to CSV. Keep this window open."
     )}
  end

  @impl true
  def handle_event("mock-action", %{"action" => action, "id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "#{action} for AP record #{id} has been queued.")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("search", search)
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  def handle_event("filter-status", %{"status" => status}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("status_filter", status)
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  def handle_event("change_limit", %{"limit" => limit}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("limit", limit)
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  def handle_event("change_page", %{"direction" => "next"}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("cursor_after", socket.assigns.next_cursor)
      |> Map.drop(["cursor_before"])

    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  def handle_event("change_page", %{"direction" => "prev"}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("cursor_before", socket.assigns.prev_cursor)
      |> Map.drop(["cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  @impl true
  def handle_info(:load_stats, socket) do
    org_id = socket.assigns.org_id

    {:noreply,
     socket
     |> assign(total_volume: get_total_volume(org_id))
     |> assign(pending_count: get_pending_count(org_id))
     |> assign(total_count: get_total_count(org_id))
     |> assign(aging_stats: get_aging_stats(org_id))}
  end

  @impl true
  def handle_info({:invoice_ingested, _invoice_id}, socket) do
    # Trigger a soft reload of the page
    {:noreply, load_invoices_page(socket)}
  end

  defp parse_amount(amount_str) do
    case Float.parse(to_string(amount_str)) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp load_invoices_page(socket) do
    %{
      org_id: org_id,
      search: search,
      status_filter: status_filter,
      limit: limit,
      cursor_before: cursor_before,
      cursor_after: cursor_after
    } = socket.assigns

    query =
      InvoiceQuery.base(org_id)
      |> InvoiceQuery.with_tenant()

    query =
      if search && String.trim(search) != "" do
        search_term = "%#{search}%"

        where(
          query,
          [i],
          ilike(i.entity_id, ^search_term) or ilike(i.sap_document_number, ^search_term)
        )
      else
        query
      end

    query =
      case status_filter do
        "Synced" ->
          InvoiceQuery.with_status(query, "ingested")

        "Paid" ->
          InvoiceQuery.with_status(query, "matched")

        "Pending" ->
          where(query, [i], i.status not in ["ingested", "matched"])

        "Overdue" ->
          now = DateTime.utc_now()
          where(query, [i], i.status not in ["matched"] and i.due_date < ^now)

        _ ->
          query
      end

    {invoices, prev_cursor, next_cursor} =
      fetch_keyset_page(query, limit, cursor_before, cursor_after)

    socket
    |> assign(:prev_cursor, prev_cursor)
    |> assign(:next_cursor, next_cursor)
    |> stream(:invoices, invoices, reset: true)
  end

  defp fetch_keyset_page(query, limit, cursor_before, cursor_after) do
    cond do
      cursor_before ->
        records =
          query
          |> where([i], i.created_at >= ^cursor_before)
          |> order_by([i], asc: i.created_at, asc: i.id)
          |> limit(^(limit + 1))
          |> Repo.all()
          |> Enum.reverse()

        if length(records) > limit do
          {tl(records), hd(records).created_at, List.last(records).created_at}
        else
          {records, nil, List.last(records) && List.last(records).created_at}
        end

      cursor_after ->
        records =
          query
          |> where([i], i.created_at <= ^cursor_after)
          |> order_by([i], desc: i.created_at, desc: i.id)
          |> limit(^(limit + 1))
          |> Repo.all()

        if length(records) > limit do
          # taking limit items, discarding the extra one, but using it to know if we have more
          has_more_records = Enum.take(records, limit)
          {has_more_records, hd(has_more_records).created_at, List.last(records).created_at}
        else
          {records, hd(records) && hd(records).created_at, nil}
        end

      true ->
        records =
          query
          |> order_by([i], desc: i.created_at, desc: i.id)
          |> limit(^(limit + 1))
          |> Repo.all()

        if length(records) > limit do
          has_more_records = Enum.take(records, limit)
          {has_more_records, nil, List.last(records).created_at}
        else
          {records, nil, nil}
        end
    end
  end

  defp get_total_count(org_id) do
    InvoiceQuery.base(org_id)
    |> Repo.aggregate(:count, :id)
  end

  defp get_pending_count(org_id) do
    InvoiceQuery.base(org_id)
    |> where([i], i.status not in ["ingested", "matched"])
    |> Repo.aggregate(:count, :id)
  end

  defp get_total_volume(org_id) do
    InvoiceQuery.base(org_id)
    |> select([i], i.amount)
    |> Repo.all()
    |> Enum.reduce(0.0, fn amount, acc ->
      acc + parse_amount(amount)
    end)
  end

  defp get_aging_stats(org_id) do
    now = DateTime.utc_now()
    day = 86400

    query =
      InvoiceQuery.base(org_id)
      |> where([i], i.status != "matched")
      |> select([i], %{amount: i.amount, due_date: i.due_date})

    invoices = Repo.all(query)

    Enum.reduce(
      invoices,
      %{current: 0.0, d30: 0.0, d60: 0.0, d90plus: 0.0},
      fn inv, acc ->
        amount = parse_amount(inv.amount)

        cond do
          is_nil(inv.due_date) or DateTime.compare(inv.due_date, now) != :lt ->
            Map.update!(acc, :current, &(&1 + amount))

          DateTime.diff(now, inv.due_date) <= 30 * day ->
            Map.update!(acc, :d30, &(&1 + amount))

          DateTime.diff(now, inv.due_date) <= 60 * day ->
            Map.update!(acc, :d60, &(&1 + amount))

          true ->
            Map.update!(acc, :d90plus, &(&1 + amount))
        end
      end
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      @keyframes rowSlideIn {
        from { opacity: 0; transform: translateY(-10px); background-color: rgba(16,185,129,0.1); }
        to { opacity: 1; transform: translateY(0); background-color: transparent; }
      }
      .animate-row {
        animation: rowSlideIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards;
      }
    </style>

    <.page_container class="px-4 md:px-6 relative animate-in fade-in slide-in-from-bottom-4 duration-500">
      <.page_header title="Accounts Payable" subtitle="Real-time ERP ledger synchronization">
        <:actions>
          <.nx_button
            variant="outline"
            phx-click="export-csv"
            icon="hero-arrow-down-tray"
            class="px-6 py-2.5 group"
          >
            Export Invoices
          </.nx_button>
          <.nx_button
            variant="primary"
            phx-click="toggle-manual-modal"
            icon="hero-plus"
            class="px-6 py-2.5 shadow-lg shadow-indigo-600/20 group"
          >
            Create Invoice
          </.nx_button>
        </:actions>
      </.page_header>
      
    <!-- Top Level KPI Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6 mb-8 relative z-10">
        <NexusWeb.NexusComponents.stat_card
          label="Total Volume Intake"
          value={"€" <> format_amount(to_string(@total_volume))}
          change="Real-time SAP sync"
          trend="up"
          icon="hero-banknotes"
        />
        <NexusWeb.NexusComponents.stat_card
          label="Total Overdue"
          value={"€" <> format_amount(to_string(@aging_stats.d30 + @aging_stats.d60 + @aging_stats.d90plus))}
          change="Awaiting reconciliation"
          trend="down"
          icon="hero-clock"
        />
        <NexusWeb.NexusComponents.stat_card
          label="Pending Review"
          value={to_string(@pending_count)}
          change="Awaiting human approval"
          trend="down"
          icon="hero-document-magnifying-glass"
        />
      </div>
      
    <!-- Aging Buckets - Visual Risk Indicator -->
      <div class="bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl p-6 mb-8 relative overflow-hidden group">
        <div class="absolute inset-0 bg-gradient-to-br from-indigo-500/5 to-transparent pointer-events-none">
        </div>
        <div class="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
          <div class="space-y-1">
            <h3 class="text-lg font-bold flex items-center gap-2">
              <span class="hero-chart-bar w-5 h-5 text-indigo-400"></span> Aging Analysis
            </h3>
            <p class="text-sm text-slate-400">
              Accounts Payable age distribution (Industry Standard)
            </p>
          </div>

          <div class="flex flex-1 w-full max-w-2xl gap-2 items-end h-16">
            <%= for {label, amount, color, _key} <- [
              {"Current", @aging_stats.current, "emerald", :current},
              {"1-30 Days", @aging_stats.d30, "amber", :d30},
              {"31-60 Days", @aging_stats.d60, "orange", :d60},
              {"60+ Days", @aging_stats.d90plus, "rose", :d90plus}
            ] do %>
              <div class="flex-1 flex flex-col items-center justify-end group/bar">
                <div class="text-[10px] font-bold text-slate-500 mb-1 opacity-0 group-hover/bar:opacity-100 transition-opacity">
                  €{format_amount(to_string(amount))}
                </div>
                <div
                  class={"w-full rounded-t-lg bg-#{color}-500/20 border-t-2 border-#{color}-500/40 hover:bg-#{color}-500/40 transition-all cursor-help"}
                  style={"height: #{max(10, min(100, if(@total_volume > 0, do: (amount / @total_volume * 100), else: 0)))}%"}
                  title={"#{label}: €#{format_amount(to_string(amount))}"}
                >
                </div>
                <div class="text-[10px] uppercase font-bold tracking-tighter text-slate-400 mt-2">
                  {label}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- High-Density Data Table Card -->
      <NexusWeb.NexusComponents.data_grid
        id="invoices-table"
        title="Inbound Invoices"
        subtitle="Manage, filter, and audit inbound invoices."
        params={@datagrid_params}
        total={@total_count}
        rows={@streams.invoices}
        row_item={fn {_, inv} -> inv end}
        row_click={fn {_, inv} -> JS.push("select_invoice", value: %{id: inv.id}) end}
      >
        <:filters>
          <div class="relative">
            <form phx-change="filter-status" class="m-0">
              <select
                name="status"
                class="bg-slate-900/40 border border-[var(--nx-border)] text-slate-300 text-xs font-medium uppercase tracking-wider rounded shadow-inner focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 py-1.5 pl-3 pr-8 appearance-none cursor-pointer focus:outline-none transition-colors hover:border-slate-500"
              >
                <%= for option <- ["All Statuses", "Synced", "Paid", "Pending", "Overdue"] do %>
                  <option value={option} selected={@status_filter == option}>{option}</option>
                <% end %>
              </select>
            </form>
            <span class="hero-chevron-down w-3 h-3 text-slate-500 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
            </span>
          </div>
        </:filters>

        <:col :let={invoice} label="Status">
          <NexusWeb.NexusComponents.badge
            variant={
              case invoice.status do
                "matched" -> "success"
                "ingested" -> "info"
                _ -> "warning"
              end
            }
            label={
              case invoice.status do
                "matched" -> "Paid"
                "ingested" -> "Synced"
                _ -> "Pending"
              end
            }
          />
        </:col>

        <:col
          :let={invoice}
          label="Organization"
          class="font-bold text-slate-400 text-[10px] uppercase tracking-wider"
        >
          {invoice.org_name || "Nexus Platform"}
        </:col>

        <:col :let={invoice} label="Vendor / SAP BELNR">
          <div class="text-slate-200 font-medium">{invoice.entity_id}</div>
          <div class="text-slate-500 font-mono text-[10px] mt-0.5">
            BELNR: {invoice.sap_document_number}
          </div>
        </:col>

        <:col :let={invoice} label="Subsidiary">
          <div class="text-slate-300">{invoice.subsidiary}</div>
          <div class="text-slate-500 font-medium tracking-wide text-[10px] uppercase mt-0.5 flex items-center gap-1">
            <span class="hero-document-text w-3 h-3"></span>
            {length(invoice.line_items || [])} Items
          </div>
        </:col>

        <:col :let={invoice} label="Due Date">
          <div class={[
            "font-medium",
            if(invoice.due_date && DateTime.compare(invoice.due_date, DateTime.utc_now()) == :lt,
              do: "text-rose-400",
              else: "text-slate-300"
            )
          ]}>
            {if invoice.due_date, do: Calendar.strftime(invoice.due_date, "%b %d, %Y"), else: "N/A"}
          </div>
          <div class="text-slate-500 font-medium tracking-wide text-[10px] uppercase mt-0.5">
            <%= cond do %>
              <% is_nil(invoice.due_date) -> %>
                <span>Pending Sync</span>
              <% DateTime.compare(invoice.due_date, DateTime.utc_now()) == :lt -> %>
                <span class="text-rose-500/80">OVERDUE</span>
              <% true -> %>
                In {div(DateTime.diff(invoice.due_date, DateTime.utc_now()), 86400)} Days
            <% end %>
          </div>
        </:col>

        <:col :let={invoice} label="Ingested">
          <div class="text-slate-300">{invoice.created_at |> Calendar.strftime("%b %d, %Y")}</div>
          <div class="text-slate-500 font-mono text-[10px] uppercase mt-0.5">
            {invoice.created_at |> Calendar.strftime("%H:%M:%S UTC")}
          </div>
        </:col>
        <:col :let={invoice} label="Amount" class="text-right">
          <div class="text-slate-200 font-medium font-mono text-sm">
            {format_currency_symbol(invoice.currency)}{format_amount(invoice.amount)}
          </div>
          <div class="text-slate-500 text-[10px] font-bold tracking-widest uppercase mt-0.5">
            {invoice.currency}
          </div>
        </:col>

        <:col :let={invoice} label="Risk/Opportunity" class="min-w-[120px]">
          <%= if discount = detect_discount(invoice) do %>
            <div class="flex items-center gap-1.5 text-emerald-400 font-bold text-[10px] uppercase tracking-wider animate-pulse">
              <span class="hero-sparkles w-3 h-3"></span>
              {discount} Discount
            </div>
            <div class="text-slate-500 text-[9px] mt-0.5">
              Pay by {format_discount_date(invoice, discount)}
            </div>
          <% else %>
            <div class="text-slate-600 text-[10px] tracking-widest uppercase font-medium">Clear</div>
          <% end %>
        </:col>

        <:action :let={invoice}>
          <div class="relative flex justify-end">
            <button
              phx-click={JS.toggle(to: "#action-menu-#{invoice.id}", in: "fade-in", out: "fade-out")}
              phx-click-away={JS.hide(to: "#action-menu-#{invoice.id}", transition: "fade-out")}
              class="text-slate-500 hover:text-indigo-400 p-1 rounded transition-colors group-hover:bg-slate-800 border border-transparent group-hover:border-slate-700/50"
            >
              <span class="hero-ellipsis-horizontal w-5 h-5"></span>
            </button>

            <div
              id={"action-menu-#{invoice.id}"}
              class="hidden absolute right-0 top-full mt-2 w-48 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-xl shadow-2xl overflow-hidden z-20 py-1"
            >
              <button
                phx-click={JS.push("mock-action", value: %{action: "View Document", id: invoice.id})}
                class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04] transition-colors"
              >
                <span class="hero-document-text w-4 h-4 text-slate-500"></span> View Document
              </button>
              <button
                phx-click={
                  JS.push("mock-action", value: %{action: "Audit Sync History", id: invoice.id})
                }
                class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04] transition-colors"
              >
                <span class="hero-clock w-4 h-4 text-slate-500"></span> Audit Sync History
              </button>
              <button
                phx-click={JS.push("mock-action", value: %{action: "Download PDF", id: invoice.id})}
                class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04] transition-colors"
              >
                <span class="hero-document-arrow-down w-4 h-4 text-slate-500"></span> Download PDF
              </button>
              <div class="my-1 border-t border-[var(--nx-border)]"></div>
              <button
                phx-click={JS.push("mock-action", value: %{action: "Flag Anomaly", id: invoice.id})}
                class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 transition-colors"
              >
                <span class="hero-flag w-4 h-4"></span> Flag Anomaly
              </button>
            </div>
          </div>
        </:action>
      </NexusWeb.NexusComponents.data_grid>
      
    <!-- Manual Entry Modal -->
      <NexusWeb.NexusComponents.nx_modal
        id="manual-entry-modal"
        show={@show_manual_modal}
        on_close="toggle-manual-modal"
      >
        <div class="text-center space-y-4">
          <div class="w-14 h-14 rounded-2xl bg-indigo-500/15 flex items-center justify-center mx-auto">
            <span class="hero-document-plus w-7 h-7 text-indigo-400"></span>
          </div>
          <h2 class="text-xl font-bold">Manual Invoice Entry</h2>
          <p class="text-sm text-slate-400">
            For compliance reasons, manual AP modifications are currently restricted. Please submit directly via your SAP instance using the standard webhook routing.
          </p>
          <div class="flex gap-3 justify-center pt-2">
            <NexusWeb.NexusComponents.nx_button variant="ghost" phx-click="toggle-manual-modal">
              Dismiss
            </NexusWeb.NexusComponents.nx_button>
          </div>
        </div>
      </NexusWeb.NexusComponents.nx_modal>
      
    <!-- Line Item Details Modal -->
      <NexusWeb.NexusComponents.nx_modal
        :if={@selected_invoice}
        id="line-item-modal"
        show={@selected_invoice != nil}
        on_close="close_modal"
      >
        <div class="space-y-6">
          <div class="flex items-center justify-between border-b border-[var(--nx-border)] pb-4">
            <div>
              <h2 class="text-xl font-bold text-white">Invoice Details</h2>
              <p class="text-sm text-slate-400 font-mono">
                SAP BELNR: {@selected_invoice.sap_document_number}
              </p>
            </div>
            <div class="flex items-center gap-3">
              <NexusWeb.NexusComponents.badge
                variant={
                  case @selected_invoice.status do
                    "matched" -> "success"
                    "ingested" -> "info"
                    _ -> "warning"
                  end
                }
                label={
                  case @selected_invoice.status do
                    "matched" -> "Paid"
                    "ingested" -> "Synced"
                    _ -> "Pending"
                  end
                }
              />

              <div class="relative">
                <button
                  phx-click={JS.toggle(to: "#modal-action-menu", in: "fade-in", out: "fade-out")}
                  phx-click-away={JS.hide(to: "#modal-action-menu", transition: "fade-out")}
                  class="p-2 text-slate-500 hover:text-white bg-white/5 rounded-lg border border-white/5 transition-colors"
                >
                  <span class="hero-ellipsis-vertical w-5 h-5"></span>
                </button>

                <div
                  id="modal-action-menu"
                  class="hidden absolute right-0 top-full mt-2 w-48 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-xl shadow-2xl overflow-hidden z-[60] py-1"
                >
                  <button class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04]">
                    <span class="hero-document-text w-4 h-4"></span> View Original PDF
                  </button>
                  <button class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04]">
                    <span class="hero-arrow-path w-4 h-4"></span> Retrigger Sync
                  </button>
                  <div class="my-1 border-t border-[var(--nx-border)]"></div>
                  <button class="w-full text-left flex items-center gap-3 px-3 py-2 text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-500/10">
                    <span class="hero-trash w-4 h-4"></span> Void Invoice
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">Vendor</div>
              <div class="text-slate-200">{@selected_invoice.entity_id}</div>
            </div>
            <div>
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">
                Due Date
              </div>
              <div class={[
                "font-mono",
                if(
                  @selected_invoice.due_date &&
                    DateTime.compare(@selected_invoice.due_date, DateTime.utc_now()) == :lt,
                  do: "text-rose-400",
                  else: "text-slate-200"
                )
              ]}>
                {if @selected_invoice.due_date,
                  do: Calendar.strftime(@selected_invoice.due_date, "%b %d, %Y"),
                  else: "N/A"}
              </div>
            </div>
            <div>
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">
                SAP BELNR
              </div>
              <div class="text-slate-200">{@selected_invoice.sap_document_number}</div>
            </div>
            <div>
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">
                Subsidiary
              </div>
              <div class="text-slate-200">
                {@selected_invoice.subsidiary || "Corporate Operations"}
              </div>
            </div>
            <div>
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">
                Risk Score
              </div>
              <div class="flex items-center gap-1.5">
                <%= if detect_discount(@selected_invoice) do %>
                  <span class="text-emerald-400 font-bold">Optimization Opportunity</span>
                  <span class="hero-bolt w-3 h-3 text-emerald-500"></span>
                <% else %>
                  <span class="text-slate-300">Standard</span>
                <% end %>
              </div>
            </div>
          </div>

          <div class="space-y-3">
            <div class="flex items-center justify-between mb-2">
              <div class="text-slate-500 uppercase text-[10px] font-bold tracking-wider">
                Line Items
              </div>
              <div class="text-slate-500 font-medium tracking-wide text-[10px] uppercase flex items-center gap-1">
                <span class="hero-layer-group w-3 h-3"></span>
                {length(@selected_invoice.line_items || [])} Items
              </div>
            </div>
            <div class="border border-[var(--nx-border)] rounded-xl overflow-hidden bg-white/[0.02]">
              <table class="w-full text-left text-sm">
                <thead>
                  <tr class="border-b border-[var(--nx-border)] bg-white/[0.04]">
                    <th class="px-4 py-2 font-medium text-slate-400">Description</th>
                    <th class="px-4 py-2 text-right font-medium text-slate-400">Amount</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-[var(--nx-border)]">
                  <%= for item <- (@selected_invoice.line_items || []) do %>
                    <tr class="hover:bg-white/[0.02] transition-colors">
                      <td class="px-4 py-3 text-slate-300">{item["description"]}</td>
                      <td class="px-4 py-3 text-right text-slate-200 font-mono">
                        {format_currency_symbol(@selected_invoice.currency)}{format_amount(
                          item["amount"]
                        )}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
                <tfoot>
                  <tr class="bg-white/[0.04] font-bold">
                    <td class="px-4 py-3 text-white">Total</td>
                    <td class="px-4 py-3 text-right text-indigo-400 font-mono">
                      {format_currency_symbol(@selected_invoice.currency)}{format_amount(
                        @selected_invoice.amount
                      )}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div class="flex justify-end pt-2">
            <NexusWeb.NexusComponents.nx_button variant="outline" size="sm" phx-click="close_modal">
              Close
            </NexusWeb.NexusComponents.nx_button>
          </div>
        </div>
      </NexusWeb.NexusComponents.nx_modal>
    </.page_container>
    """
  end

  defp format_currency_symbol("USD"), do: "$"
  defp format_currency_symbol("EUR"), do: "€"
  defp format_currency_symbol("GBP"), do: "£"
  defp format_currency_symbol(_), do: ""

  defp format_amount(amount_str) when is_binary(amount_str) do
    case Float.parse(amount_str) do
      {float, _} ->
        [int_part, dec_part] = :erlang.float_to_binary(float, decimals: 2) |> String.split(".")

        formatted_int =
          int_part
          |> String.graphemes()
          |> Enum.reverse()
          |> Enum.chunk_every(3)
          |> Enum.map(&Enum.reverse/1)
          |> Enum.reverse()
          |> Enum.map(&Enum.join/1)
          |> Enum.join(",")

        "#{formatted_int}.#{dec_part}"

      :error ->
        amount_str
    end
  end

  defp format_amount(amount), do: to_string(amount)

  defp detect_discount(invoice) do
    # Search for patterns like 2/10, 1/15, 3/7 in line items or document number (mock logic for demo)
    content =
      Enum.map(invoice.line_items || [], fn item -> item["description"] end) |> Enum.join(" ")

    cond do
      String.contains?(content, "2/10") -> "2/10"
      String.contains?(content, "1/15") -> "1/15"
      String.contains?(content, "3/7") -> "3/7"
      # Mock: certain entities always provide discounts in this demo
      String.contains?(invoice.entity_id, "Logistics") -> "2/10"
      true -> nil
    end
  end

  defp format_discount_date(invoice, discount_type) do
    days =
      case discount_type do
        "2/10" -> 10
        "1/15" -> 15
        "3/7" -> 7
        _ -> 10
      end

    invoice.created_at
    |> DateTime.to_date()
    |> Date.add(days)
    |> Calendar.strftime("%b %d")
  end
end
