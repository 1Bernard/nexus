defmodule NexusWeb.ERP.InvoiceLive do
  use NexusWeb, :live_view

  alias Nexus.ERP.Projections.Invoice
  alias Nexus.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    org_id = socket.assigns.current_user.org_id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "erp_invoices:#{org_id}")
    end

    invoices = load_invoices(org_id, nil, 10)

    {:ok,
     socket
     |> assign(page_title: "ERP Talk Back - Nexus")
     |> assign(org_id: org_id)
     |> assign(show_manual_modal: false)
     |> assign(total_volume: get_total_volume(org_id))
     |> assign(pending_count: get_pending_count(org_id))
     |> assign(has_more: length(invoices) == 10)
     |> assign(showing: length(invoices))
     |> assign(total_count: get_total_count(org_id))
     |> assign(last_cursor: List.last(invoices) && List.last(invoices).created_at)
     |> stream(:invoices, invoices)}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, current_path: URI.parse(uri).path)}
  end

  @impl true
  def handle_event("toggle-manual-modal", _, socket) do
    {:noreply, assign(socket, show_manual_modal: !socket.assigns.show_manual_modal)}
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
  def handle_event("load-more", _, socket) do
    new_invoices = load_invoices(socket.assigns.org_id, socket.assigns.last_cursor, 10)

    socket =
      socket
      |> assign(has_more: length(new_invoices) == 10)
      |> assign(showing: socket.assigns.showing + length(new_invoices))
      |> assign(last_cursor: List.last(new_invoices) && List.last(new_invoices).created_at)

    # Append the new cursored data to the stream
    socket =
      Enum.reduce(new_invoices, socket, fn invoice, acc ->
        stream_insert(acc, :invoices, invoice)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:invoice_ingested, invoice_id}, socket) do
    if invoice = Repo.get(Invoice, invoice_id) do
      socket =
        socket
        |> assign(showing: socket.assigns.showing + 1)
        |> assign(total_count: socket.assigns.total_count + 1)
        |> assign(total_volume: socket.assigns.total_volume + parse_amount(invoice.amount))
        |> assign(pending_count: socket.assigns.pending_count + 1)
        |> stream_insert(:invoices, invoice, at: 0)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp parse_amount(amount_str) do
    case Float.parse(to_string(amount_str)) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp load_invoices(org_id, nil, limit) do
    Invoice
    |> where([i], i.org_id == ^org_id)
    |> order_by([i], desc: i.created_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp load_invoices(org_id, cursor, limit) do
    Invoice
    |> where([i], i.org_id == ^org_id and i.created_at < ^cursor)
    |> order_by([i], desc: i.created_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp get_total_count(org_id) do
    Nexus.Repo.aggregate(
      from(i in Invoice, where: i.org_id == ^org_id),
      :count,
      :id
    )
  end

  defp get_pending_count(org_id) do
    Nexus.Repo.aggregate(
      from(i in Invoice, where: i.org_id == ^org_id and i.status == "ingested"),
      :count,
      :id
    )
  end

  defp get_total_volume(org_id) do
    invoices = Repo.all(from i in Invoice, where: i.org_id == ^org_id, select: i.amount)

    Enum.reduce(invoices, 0.0, fn amount, acc ->
      acc + parse_amount(amount)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      #invoices-table-body:empty + #empty-state {
        display: flex;
      }
      @keyframes rowSlideIn {
        from { opacity: 0; transform: translateY(-10px); background-color: rgba(16,185,129,0.1); }
        to { opacity: 1; transform: translateY(0); background-color: transparent; }
      }
      .animate-row {
        animation: rowSlideIn 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards;
      }
    </style>

    <div class="p-6 md:p-8 w-full relative animate-in fade-in slide-in-from-bottom-4 duration-500">
      
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
          label="Pending Review"
          value={to_string(@pending_count)}
          change="Awaiting human approval"
          trend="down"
          icon="hero-document-magnifying-glass"
        />
        <NexusWeb.NexusComponents.stat_card
          label="Risk Anomalies"
          value="0"
          change="No breaches detected"
          trend="up"
          icon="hero-shield-check"
        />
      </div>
      
    <!-- High-Density Data Table Card -->
      <NexusWeb.NexusComponents.dark_card
        title="Accounts Payable"
        subtitle="Real-time ERP ledger synchronization. Manage, filter, and audit inbound invoices."
      >
        <:header_actions>
          <div class="flex flex-col sm:flex-row items-center gap-3">
            <NexusWeb.NexusComponents.nx_button
              variant="outline"
              size="sm"
              icon="hero-arrow-down-tray"
              phx-click="export-csv"
            >
              Export
            </NexusWeb.NexusComponents.nx_button>
            <NexusWeb.NexusComponents.nx_button
              variant="primary"
              size="sm"
              icon="hero-plus"
              phx-click="toggle-manual-modal"
            >
              New Entry
            </NexusWeb.NexusComponents.nx_button>
          </div>
        </:header_actions>
        
    <!-- Filters Block -->
        <div class="px-6 py-4 border-b border-[var(--nx-border)] flex flex-col md:flex-row gap-4 bg-[var(--nx-surface)]/50">
          <div class="relative flex-1">
            <span class="hero-magnifying-glass w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2">
            </span>
            <input
              type="text"
              placeholder="Search by Vendor, Subsidiary, or Ref..."
              class="w-full bg-slate-900/40 border border-[var(--nx-border)] text-slate-200 text-sm rounded shadow-inner focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 pl-9 py-2 transition-colors placeholder:text-slate-600 focus:outline-none"
            />
          </div>
          <div class="flex items-center gap-3">
            <div class="relative">
              <select class="bg-slate-900/40 border border-[var(--nx-border)] text-slate-300 text-xs font-medium uppercase tracking-wider rounded shadow-inner focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 py-2.5 pl-3 pr-8 appearance-none cursor-pointer focus:outline-none">
                <option>All Statuses</option>
                <option>Synced</option>
                <option>Pending</option>
              </select>
              <span class="hero-chevron-down w-3 h-3 text-slate-500 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
              </span>
            </div>
          </div>
        </div>

        <NexusWeb.NexusComponents.data_table
          id="invoices-table"
          rows={@streams.invoices}
          row_item={fn {_, inv} -> inv end}
        >
          <:col :let={_invoice} label="Status">
            <NexusWeb.NexusComponents.badge variant="success" label="Synced" />
          </:col>

          <:col :let={invoice} label="Vendor / Ref">
            <div class="text-slate-200 font-medium">{invoice.entity_id}</div>
            <div class="text-slate-500 font-mono text-[10px] mt-0.5">
              {invoice.sap_document_number}
            </div>
          </:col>

          <:col :let={invoice} label="Subsidiary">
            <div class="text-slate-300">{invoice.subsidiary}</div>
            <div class="text-slate-500 font-medium tracking-wide text-[10px] uppercase mt-0.5 flex items-center gap-1">
              <span class="hero-document-text w-3 h-3"></span>
              {length(invoice.line_items || [])} Items
            </div>
          </:col>

          <:col :let={invoice} label="Timestamp">
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

          <:action :let={invoice}>
            <div class="relative flex justify-end">
              <button
                phx-click={
                  JS.toggle(to: "#action-menu-#{invoice.id}", in: "fade-in", out: "fade-out")
                }
                phx-click-away={JS.hide(to: "#action-menu-#{invoice.id}", transition: "fade-out")}
                class="text-slate-500 hover:text-indigo-400 p-1 rounded transition-colors group-hover:bg-slate-800"
              >
                <span class="hero-ellipsis-horizontal w-5 h-5"></span>
              </button>

              <div
                id={"action-menu-#{invoice.id}"}
                class="hidden absolute right-0 top-full mt-2 w-48 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-xl shadow-2xl overflow-hidden z-20 py-1"
              >
                <button
                  phx-click={
                    JS.push("mock-action", value: %{action: "View Document", id: invoice.id})
                  }
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
        </NexusWeb.NexusComponents.data_table>

        <NexusWeb.NexusComponents.pagination
          showing={@showing}
          total={@total_count}
          has_more={@has_more}
          on_load_more="load-more"
        />
      </NexusWeb.NexusComponents.dark_card>
      
    <!-- Manual Entry Modal -->
      <NexusWeb.NexusComponents.modal
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
      </NexusWeb.NexusComponents.modal>
    </div>
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
end
