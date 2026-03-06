defmodule NexusWeb.Treasury.ReconciliationLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      org_id = socket.assigns.current_user.org_id
      Phoenix.PubSub.subscribe(Nexus.PubSub, "reconciliations:#{org_id}")
      Phoenix.PubSub.subscribe(Nexus.PubSub, "erp_invoices:#{org_id}")
      Phoenix.PubSub.subscribe(Nexus.PubSub, "erp_statements:#{org_id}")
      send(self(), :load_stats)
    end

    socket =
      socket
      |> assign(:selected_invoice_id, nil)
      |> assign(:selected_line_id, nil)
      |> assign(:invoice_search, "")
      |> assign(:line_search, "")
      |> assign(:variance_reason, nil)
      |> assign(:filter_date_from, "")
      |> assign(:filter_date_to, "")
      |> assign(:filter_type, "all")
      # Setup datagrid state
      |> assign(datagrid_params: %{})
      |> assign(limit: 25)
      |> assign(cursor_before: nil)
      |> assign(cursor_after: nil)
      |> assign(search: nil)
      # Stats placeholder
      |> assign(:auto_matched_count, 0)
      |> assign(:auto_match_rate, 0)
      |> load_unmatched()
      |> load_reconciliations_page()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    type = params["type"] || socket.assigns.filter_type

    socket =
      socket
      |> assign(:page_title, "Match Engine")
      |> assign(current_path: URI.parse(uri).path)
      |> assign(datagrid_params: params)
      |> assign(search: params["search"])
      |> assign(filter_date_from: params["date_from"] || socket.assigns.filter_date_from)
      |> assign(filter_date_to: params["date_to"] || socket.assigns.filter_date_to)
      |> assign(filter_type: type)
      |> assign(limit: String.to_integer(params["limit"] || "25"))
      |> assign(cursor_after: params["cursor_after"])
      |> assign(cursor_before: params["cursor_before"])
      |> load_reconciliations_page()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <.page_header title="Match Engine" subtitle="Cross-system reconciliation & anomaly detection">
        <:actions>
          <.dark_card class="px-4 py-2 flex items-center gap-4 bg-emerald-500/5 border-emerald-500/10">
            <div class="flex flex-col">
              <span class="text-[9px] uppercase tracking-widest text-slate-500 font-bold">
                Auto-Match Rate
              </span>
              <span class="text-xs text-emerald-400 font-black uppercase tracking-tight">
                {@auto_match_rate}% Efficiency
              </span>
            </div>
            <div class="flex flex-col border-l border-white/5 pl-4">
              <span class="text-[9px] uppercase tracking-widest text-slate-500 font-bold">
                Daily Velocity
              </span>
              <span class="text-xs text-indigo-400 font-black uppercase tracking-tight">
                {@auto_matched_count} Matched
              </span>
            </div>
            <div class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></div>
          </.dark_card>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Column 1: Unmatched Invoices --%>
        <.dark_card class="p-0 flex flex-col min-h-[400px]">
          <div class="p-6 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                <span class="hero-document-text w-4 h-4 text-indigo-400"></span>
              </div>
              <h2 class="text-xs font-bold text-slate-300 uppercase tracking-[0.2em]">
                Pending Invoices
              </h2>
            </div>
            <span class="px-2 py-1 rounded text-[10px] font-black bg-slate-800 text-slate-400 uppercase tracking-widest">
              {length(@unmatched_invoices)} Unmatched
            </span>
          </div>

          <div class="px-6 py-3 border-b border-white/5 bg-white/[0.01]">
            <div class="relative">
              <span class="hero-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-500">
              </span>
              <input
                type="text"
                phx-keyup="search_invoices"
                placeholder="Search invoices..."
                value={@invoice_search}
                class="w-full bg-slate-900/50 border-slate-700/50 rounded-lg py-1.5 pl-9 pr-3 text-xs text-slate-300 placeholder:text-slate-600 focus:ring-1 focus:ring-indigo-500 font-sans outline-none"
              />
            </div>
          </div>

          <div class="flex-1 overflow-y-auto max-h-[500px] scroll-soft">
            <%= if Enum.empty?(@unmatched_invoices) do %>
              <div class="h-full flex flex-col items-center justify-center py-20 opacity-20">
                <span class="hero-check-badge w-12 h-12 mb-4"></span>
                <p class="text-xs uppercase tracking-[0.2em] font-bold">Queue All Clear</p>
              </div>
            <% else %>
              <table class="w-full text-left border-collapse">
                <thead class="sticky top-0 bg-slate-900/90 backdrop-blur-md z-10">
                  <tr class="border-b border-white/5">
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                      Ref
                    </th>
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">
                      Amount
                    </th>
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                      Date
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/[0.03]">
                  <%= for inv <- @unmatched_invoices do %>
                    <tr
                      phx-click="select_invoice"
                      phx-value-id={inv.id}
                      class={[
                        "group hover:bg-white/[0.02] transition-colors cursor-pointer",
                        @selected_invoice_id == inv.id &&
                          "bg-indigo-500/10 border-l-2 border-indigo-500"
                      ]}
                    >
                      <td class="p-4">
                        <div class="flex flex-col">
                          <span class="text-xs font-bold text-slate-200 group-hover:text-white transition-colors">
                            {inv.sap_document_number}
                          </span>
                          <span class="text-[9px] text-slate-500 font-mono italic">
                            {inv.subsidiary}
                          </span>
                        </div>
                      </td>
                      <td class="p-4 text-right">
                        <span class="text-xs font-mono font-bold text-white">
                          {inv.amount} {inv.currency}
                        </span>
                      </td>
                      <td class="p-4">
                        <span class="text-[10px] text-slate-500 font-medium">
                          {Calendar.strftime(inv.created_at, "%d %b %Y")}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        </.dark_card>

        <%!-- Column 2: Unmatched Bank Lines --%>
        <.dark_card class="p-0 flex flex-col min-h-[400px]">
          <div class="p-6 border-b border-white/5 flex items-center justify-between bg-white/[0.02]">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center">
                <span class="hero-banknotes w-4 h-4 text-amber-400"></span>
              </div>
              <h2 class="text-xs font-bold text-slate-300 uppercase tracking-[0.2em]">
                Bank Statement Exceptions
              </h2>
            </div>
            <span class="px-2 py-1 rounded text-[10px] font-black bg-slate-800 text-slate-400 uppercase tracking-widest">
              {length(@unmatched_lines)} Unmatched
            </span>
          </div>

          <div class="px-6 py-3 border-b border-white/5 bg-white/[0.01]">
            <div class="relative">
              <span class="hero-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-500">
              </span>
              <input
                type="text"
                phx-keyup="search_lines"
                placeholder="Search bank lines..."
                value={@line_search}
                class="w-full bg-slate-900/50 border-slate-700/50 rounded-lg py-1.5 pl-9 pr-3 text-xs text-slate-300 placeholder:text-slate-600 focus:ring-1 focus:ring-indigo-500 font-sans outline-none"
              />
            </div>
          </div>

          <div class="flex-1 overflow-y-auto max-h-[500px] scroll-soft">
            <%= if Enum.empty?(@unmatched_lines) do %>
              <div class="h-full flex flex-col items-center justify-center py-20 opacity-20">
                <span class="hero-check-badge w-12 h-12 mb-4"></span>
                <p class="text-xs uppercase tracking-[0.2em] font-bold">All Lines Reconciled</p>
              </div>
            <% else %>
              <table class="w-full text-left border-collapse">
                <thead class="sticky top-0 bg-slate-900/90 backdrop-blur-md z-10">
                  <tr class="border-b border-white/5">
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                      Reference
                    </th>
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">
                      Value
                    </th>
                    <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                      Bank Date
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/[0.03]">
                  <%= for line <- @unmatched_lines do %>
                    <tr
                      phx-click="select_line"
                      phx-value-id={line.id}
                      class={[
                        "group hover:bg-white/[0.02] transition-colors cursor-pointer",
                        @selected_line_id == line.id && "bg-amber-500/10 border-l-2 border-amber-500"
                      ]}
                    >
                      <td class="p-4">
                        <div class="flex flex-col">
                          <span class="text-xs font-bold text-slate-200 group-hover:text-white transition-colors">
                            {line.ref}
                          </span>
                          <span class="text-[9px] text-slate-500 line-clamp-1 truncate max-w-[150px]">
                            {line.narrative}
                          </span>
                        </div>
                      </td>
                      <td class="p-4 text-right">
                        <span class="text-xs font-mono font-bold text-white">
                          {line.amount} {line.currency}
                        </span>
                      </td>
                      <td class="p-4">
                        <span class="text-[10px] text-slate-500 font-medium">
                          {line.date}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        </.dark_card>
      </div>

      <%!-- Match Actions Modal --%>
      <.modal
        :if={@selected_invoice_id && @selected_line_id}
        id="match-actions-modal"
        show={@selected_invoice_id && @selected_line_id}
        on_close={JS.push("clear_selection")}
      >
        <% inv = Enum.find(@unmatched_invoices, &(&1.id == @selected_invoice_id))
        line = Enum.find(@unmatched_lines, &(&1.id == @selected_line_id))
        inv_amount = Decimal.new(inv.amount)
        line_amount = Decimal.new(line.amount)
        variance = Decimal.sub(line_amount, inv_amount)
        is_exact = Decimal.eq?(inv_amount, line_amount) %>
        <div class="flex flex-col gap-8">
          <div class="flex flex-col">
            <h2 class="text-xl font-serif italic font-bold text-white mb-1">Manual Reconciliation</h2>
            <p class="text-slate-500 text-sm">Verify pair matching and reason for variance if any.</p>
          </div>

          <div class="grid grid-cols-1 gap-6 py-6 border-y border-white/5">
            <div class="flex flex-col gap-4">
              <span class="text-[10px] uppercase tracking-widest text-slate-500 font-bold">
                Pair Selection
              </span>
              <div class="flex items-center justify-between p-4 rounded-2xl bg-white/[0.03] border border-white/5">
                <div class="flex flex-col">
                  <span class="text-[10px] text-indigo-400 font-mono italic">
                    #{inv.sap_document_number}
                  </span>
                  <span class="text-sm font-bold text-white">{inv.amount} {inv.currency}</span>
                </div>
                <div class="w-8 h-8 rounded-full bg-white/5 flex items-center justify-center">
                  <span class="hero-arrows-right-left w-4 h-4 text-slate-400"></span>
                </div>
                <div class="flex flex-col text-right">
                  <span class="text-[10px] text-amber-400 font-mono italic">#{line.ref}</span>
                  <span class="text-sm font-bold text-white">{line.amount} {line.currency}</span>
                </div>
              </div>
            </div>

            <div class="flex flex-col gap-4">
              <div class="flex items-center justify-between">
                <span class="text-[10px] uppercase tracking-widest text-slate-500 font-bold">
                  Variance
                </span>
                <span class={[
                  "text-sm font-mono font-bold",
                  if(is_exact, do: "text-emerald-400", else: "text-rose-400")
                ]}>
                  {Decimal.to_string(variance)} {line.currency}
                </span>
              </div>

              <div class="p-4 rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-between">
                <%= if is_exact do %>
                  <div class="flex items-center gap-2">
                    <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
                    <span class="text-xs text-emerald-400 font-bold uppercase tracking-tight">
                      Exact Match Confirmed
                    </span>
                  </div>
                <% else %>
                  <div class="flex flex-col gap-3 w-full">
                    <div class="flex items-center justify-between">
                      <span class="text-[10px] text-rose-400 font-black uppercase tracking-widest">
                        Needs Reason
                      </span>
                    </div>
                    <select
                      phx-change="set_variance_reason"
                      class="w-full bg-slate-900 border-white/10 text-sm text-slate-300 rounded-xl px-4 py-2.5 outline-none focus:ring-1 focus:ring-indigo-500 transition-all"
                    >
                      <option value="">Select variance reason...</option>
                      <option value="bank_fee" selected={@variance_reason == "bank_fee"}>
                        Bank Fee
                      </option>
                      <option value="fx_diff" selected={@variance_reason == "fx_diff"}>
                        FX Difference
                      </option>
                      <option value="overpayment" selected={@variance_reason == "overpayment"}>
                        Overpayment
                      </option>
                      <option value="underpayment" selected={@variance_reason == "underpayment"}>
                        Underpayment
                      </option>
                      <option value="other" selected={@variance_reason == "other"}>Other</option>
                    </select>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <button
              phx-click="match_selected"
              disabled={!is_exact && is_nil(@variance_reason)}
              class="flex-1 py-3 px-6 rounded-2xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white text-sm font-bold transition-all shadow-xl shadow-indigo-500/20 active:scale-95"
            >
              Confirm Reconciliation
            </button>
            <button
              phx-click={JS.push("clear_selection")}
              class="px-6 py-3 rounded-2xl bg-white/5 hover:bg-white/10 text-slate-300 font-bold text-sm transition-all"
            >
              Cancel
            </button>
          </div>
        </div>
      </.modal>

      <NexusWeb.NexusComponents.data_grid
        id="reconciliations-table"
        title="Matched Ledger (Audit Trail)"
        subtitle="Historical log of all reconciliations"
        params={%{}}
        total={length(@reconciliations)}
        rows={@reconciliations}
        row_item={fn r -> r end}
        row_click={nil}
      >
        <:filters>
          <form
            phx-change="filter_ledger"
            class="flex items-center gap-2 m-0 bg-slate-900/40 border border-slate-800 rounded-xl p-1"
          >
            <input
              type="date"
              name="date_from"
              value={@filter_date_from}
              class="bg-transparent border-none focus:ring-0 text-xs text-slate-300 w-[110px] py-1 cursor-pointer"
            />
            <span class="text-slate-500 text-xs font-bold px-1">→</span>
            <input
              type="date"
              name="date_to"
              value={@filter_date_to}
              class="bg-transparent border-none focus:ring-0 text-xs text-slate-300 w-[110px] py-1 cursor-pointer"
            />
            <div class="h-4 w-px bg-slate-700/50 mx-1"></div>
            <select
              name="type"
              class="bg-transparent border-none focus:ring-0 text-xs text-slate-300 py-1 pr-6 cursor-pointer font-medium uppercase tracking-wider appearance-none"
            >
              <option value="all" selected={@filter_type == "all"}>All Types</option>
              <option value="auto" selected={@filter_type == "auto"}>Auto</option>
              <option value="manual" selected={@filter_type == "manual"}>Manual</option>
              <option value="pending" selected={@filter_type == "pending"}>Pending</option>
              <option value="rejected" selected={@filter_type == "rejected"}>Rejected</option>
            </select>
          </form>
        </:filters>

        <:primary_actions>
          <div class="flex items-center gap-2 text-[9px] text-slate-500 uppercase tracking-widest font-bold border-r border-white/5 pr-4 mr-2">
            <span class="hero-check-badge w-3.5 h-3.5 text-emerald-500"></span> Verified
          </div>
          <NexusWeb.NexusComponents.nx_button
            variant="outline"
            size="sm"
            icon="hero-arrow-down-tray"
            phx-click="export_csv"
          >
            Export
          </NexusWeb.NexusComponents.nx_button>
        </:primary_actions>

        <:col :let={_recon} label="" class="w-12 text-center">
          <span class="hero-lock-closed w-3.5 h-3.5 text-slate-700"></span>
        </:col>

        <:col :let={recon} label="Match Type" class="w-32">
          <% is_manual =
            String.contains?(recon.reconciliation_id, "MANUAL") or
              Enum.at(String.split(recon.reconciliation_id, "-"), 0) |> String.length() > 30 %>
          <div class="flex items-start gap-2">
            <%= if is_manual do %>
              <div
                class="w-6 h-6 rounded-md bg-amber-500/10 flex items-center justify-center shrink-0"
                title="Manual Match"
              >
                <span class="hero-user w-3.5 h-3.5 text-amber-500"></span>
              </div>
              <div class="flex flex-col">
                <span class="text-[9px] font-bold text-slate-400 uppercase tracking-wider">
                  Manual
                </span>
                <%= if recon.actor_email do %>
                  <span
                    class="text-[9px] text-slate-500 font-medium truncate max-w-[100px]"
                    title={recon.actor_email}
                  >
                    {recon.actor_email}
                  </span>
                <% end %>
              </div>
            <% else %>
              <div
                class="w-6 h-6 rounded-md bg-indigo-500/10 flex items-center justify-center"
                title="Auto Match"
              >
                <span class="hero-bolt w-3.5 h-3.5 text-indigo-400"></span>
              </div>
              <span class="text-[9px] font-bold text-slate-400 uppercase tracking-wider">Auto</span>
            <% end %>
          </div>
        </:col>

        <:col :let={recon} label="References (SAP / Bank)">
          <div class="flex flex-col gap-0.5">
            <div class="flex items-center gap-2">
              <span class="text-[10px] font-mono text-indigo-400">SAP:</span>
              <span class="text-xs font-bold text-slate-300">{recon.invoice_id}</span>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-[10px] font-mono text-amber-400">BNK:</span>
              <span class="text-[11px] text-slate-500 font-medium truncate max-w-[150px]">
                {recon.statement_line_id}
              </span>
            </div>
          </div>
        </:col>

        <:col :let={recon} label="Matched" class="text-right">
          <span class="text-xs font-mono font-bold text-white">
            {recon.amount} {recon.currency}
          </span>
        </:col>

        <:col :let={recon} label="Variance" class="text-right">
          <%= if not Decimal.equal?(recon.variance || Decimal.new(0), Decimal.new(0)) do %>
            <div class="flex flex-col items-end">
              <span class="text-[10px] font-mono font-bold text-rose-400">
                {recon.variance} {recon.currency}
              </span>
              <span class="text-[8px] text-slate-600 uppercase font-black">
                {recon.variance_reason || "Reconciled Diff"}
              </span>
            </div>
          <% else %>
            <span class="text-[10px] font-mono text-slate-700">None</span>
          <% end %>
        </:col>

        <:col :let={recon} label="Timestamp">
          <div class="flex flex-col items-start gap-1">
            <span class="text-[10px] text-slate-300 font-bold">
              {Calendar.strftime(recon.matched_at, "%d %b %Y")}
            </span>
            <span class="text-[9px] text-slate-500 uppercase tracking-widest font-mono">
              {Calendar.strftime(recon.matched_at, "%H:%M:%S UTC")}
            </span>
          </div>
        </:col>

        <:action :let={recon}>
          <%= cond do %>
            <% recon.status == :matched -> %>
              <div class="flex flex-col items-end gap-2">
                <span class="text-[9px] font-black text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded uppercase tracking-widest border border-emerald-500/20">
                  Matched
                </span>
                <button
                  phx-click="reverse_match"
                  phx-value-id={recon.reconciliation_id}
                  class="text-[9px] font-bold text-slate-500 hover:text-rose-400 transition-colors uppercase tracking-widest"
                >
                  Reverse Match
                </button>
              </div>
            <% recon.status == :pending -> %>
              <div class="flex flex-col items-end gap-2">
                <span class="text-[9px] font-black text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded uppercase tracking-widest border border-amber-500/20 animate-pulse">
                  Pending Approval
                </span>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="approve_match"
                    phx-value-id={recon.reconciliation_id}
                    class="px-2 py-1 text-[10px] font-bold text-emerald-400 bg-emerald-500/10 hover:bg-emerald-500/20 rounded transition-colors uppercase tracking-wider"
                  >
                    Approve
                  </button>
                  <button
                    phx-click="reject_match"
                    phx-value-id={recon.reconciliation_id}
                    class="px-2 py-1 text-[10px] font-bold text-rose-400 bg-rose-500/10 hover:bg-rose-500/20 rounded transition-colors uppercase tracking-wider"
                  >
                    Reject
                  </button>
                </div>
              </div>
            <% recon.status == :reversed -> %>
              <span class="text-[10px] font-bold text-rose-500/70 border border-rose-500/20 px-2 py-0.5 rounded uppercase tracking-wider bg-rose-500/5">
                Reversed
              </span>
            <% recon.status == :rejected -> %>
              <span class="text-[10px] font-bold text-slate-500 border border-slate-500/20 px-2 py-0.5 rounded uppercase tracking-wider bg-slate-500/5">
                Rejected
              </span>
            <% true -> %>
              <span class="text-[10px] font-bold text-slate-500 border border-slate-500/20 px-2 py-0.5 rounded uppercase tracking-wider">
                {recon.status}
              </span>
          <% end %>
        </:action>
      </NexusWeb.NexusComponents.data_grid>
    </.page_container>
    """
  end

  @impl true
  def handle_info(:load_stats, socket) do
    org_id = socket.assigns.current_user.org_id
    stats = Treasury.get_reconciliation_stats(org_id)

    {:noreply,
     socket
     |> assign(:auto_matched_count, stats.auto_matched_count)
     |> assign(:auto_match_rate, stats.match_rate)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket |> load_unmatched() |> load_reconciliations_page()}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("search", search)
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/reconciliation?#{params}")}
  end

  @impl true
  def handle_event("change_limit", %{"limit" => limit}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("limit", limit)
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/reconciliation?#{params}")}
  end

  @impl true
  def handle_event("change_page", %{"direction" => "next"}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("cursor_after", socket.assigns.next_cursor)
      |> Map.drop(["cursor_before"])

    {:noreply, push_patch(socket, to: ~p"/reconciliation?#{params}")}
  end

  @impl true
  def handle_event("change_page", %{"direction" => "prev"}, socket) do
    params =
      socket.assigns.datagrid_params
      |> Map.put("cursor_before", socket.assigns.prev_cursor)
      |> Map.drop(["cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/reconciliation?#{params}")}
  end

  def handle_event("filter_ledger", params, socket) do
    new_params =
      socket.assigns.datagrid_params
      |> Map.merge(%{
        "date_from" => params["date_from"],
        "date_to" => params["date_to"],
        "type" => params["type"]
      })
      |> Map.drop(["cursor_before", "cursor_after"])

    {:noreply, push_patch(socket, to: ~p"/reconciliation?#{new_params}")}
  end

  @impl true
  def handle_event("select_invoice", %{"id" => id}, socket) do
    # Toggle selection
    new_id = if socket.assigns.selected_invoice_id == id, do: nil, else: id
    {:noreply, assign(socket, :selected_invoice_id, new_id)}
  end

  @impl true
  def handle_event("select_line", %{"id" => id}, socket) do
    # Toggle selection
    new_id = if socket.assigns.selected_line_id == id, do: nil, else: id
    {:noreply, assign(socket, :selected_line_id, new_id)}
  end

  @impl true
  def handle_event("search_invoices", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:invoice_search, query) |> load_unmatched()}
  end

  @impl true
  def handle_event("search_lines", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:line_search, query) |> load_unmatched()}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     assign(socket, selected_invoice_id: nil, selected_line_id: nil, variance_reason: nil)}
  end

  @impl true
  def handle_event("set_variance_reason", %{"value" => reason}, socket) do
    reason = if reason == "", do: nil, else: reason
    {:noreply, assign(socket, :variance_reason, reason)}
  end

  @impl true
  def handle_event("match_selected", _params, socket) do
    %{
      selected_invoice_id: inv_id,
      selected_line_id: line_id,
      variance_reason: reason,
      current_user: user
    } = socket.assigns

    if inv_id && line_id do
      inv = Enum.find(socket.assigns.unmatched_invoices, &(&1.id == inv_id))
      line = Enum.find(socket.assigns.unmatched_lines, &(&1.id == line_id))

      # Calculate variance to persist
      inv_amount = Decimal.new(inv.amount)
      line_amount = Decimal.new(line.amount)
      variance = Decimal.sub(line_amount, inv_amount)

      case Treasury.reconcile_manually(user.org_id, inv_id, line_id, variance, reason, user.email) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "Manual match initiated successfully.")
           |> assign(:selected_invoice_id, nil)
           |> assign(:selected_line_id, nil)
           |> assign(:variance_reason, nil)}

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to initiate manual match.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reverse_match", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Treasury.reverse_reconciliation(user.org_id, id, user.email) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Match successfully reversed.")
         |> load_unmatched()
         |> load_reconciliations_page()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to reverse match.")}
    end
  end

  @impl true
  def handle_event("approve_match", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Treasury.approve_reconciliation(user.org_id, id, user.email) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Match approved successfully.")
         |> load_unmatched()
         |> load_reconciliations_page()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to approve match.")}
    end
  end

  @impl true
  def handle_event("reject_match", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Treasury.reject_reconciliation(user.org_id, id, user.email) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Match rejected.")
         |> load_unmatched()
         |> load_reconciliations_page()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to reject match.")}
    end
  end

  defp load_unmatched(socket) do
    org_id = socket.assigns.current_user.org_id

    invoices =
      Treasury.list_unmatched_invoices(org_id)
      |> filter_items(socket.assigns.invoice_search, [:sap_document_number, :subsidiary, :amount])

    lines =
      Treasury.list_unmatched_statement_lines(org_id)
      |> filter_items(socket.assigns.line_search, [:ref, :narrative, :amount])

    socket
    |> assign(:unmatched_invoices, invoices)
    |> assign(:unmatched_lines, lines)
  end

  defp load_reconciliations_page(socket) do
    %{
      current_user: user,
      limit: limit,
      cursor_before: cursor_before,
      cursor_after: cursor_after,
      filter_date_from: date_from,
      filter_date_to: date_to,
      filter_type: type,
      search: search
    } = socket.assigns

    import Ecto.Query

    base_query =
      from(r in Nexus.Treasury.Projections.Reconciliation,
        where: r.org_id == ^user.org_id
      )

    query =
      if search && String.trim(search) != "" do
        search_term = "%#{search}%"

        where(
          base_query,
          [r],
          ilike(r.invoice_id, ^search_term) or ilike(r.statement_line_id, ^search_term)
        )
      else
        base_query
      end

    query =
      if date_from && date_from != "" do
        # rudimentary YYYY-MM-DD check
        if String.length(date_from) == 10 do
          where(query, [r], fragment("date(?)", r.matched_at) >= ^date_from)
        else
          query
        end
      else
        query
      end

    query =
      if date_to && date_to != "" do
        if String.length(date_to) == 10 do
          where(query, [r], fragment("date(?)", r.matched_at) <= ^date_to)
        else
          query
        end
      else
        query
      end

    query =
      case type do
        "auto" -> where(query, [r], r.actor_email == "system@nexus.ai")
        "manual" -> where(query, [r], r.actor_email != "system@nexus.ai")
        "pending" -> where(query, [r], r.status == :pending)
        "rejected" -> where(query, [r], r.status == :rejected)
        _ -> query
      end

    {reconciliations, prev_cursor, next_cursor} =
      fetch_keyset_page(query, limit, cursor_before, cursor_after)

    socket
    |> assign(:prev_cursor, prev_cursor)
    |> assign(:next_cursor, next_cursor)
    # Using list instead of stream for existing UI hookup
    |> assign(:reconciliations, reconciliations)
  end

  defp fetch_keyset_page(query, limit, cursor_before, cursor_after) do
    import Ecto.Query

    cond do
      cursor_before ->
        records =
          query
          |> where([r], r.reconciliation_id > ^cursor_before)
          |> order_by([r], asc: r.reconciliation_id)
          |> limit(^(limit + 1))
          |> Nexus.Repo.all()
          |> Enum.reverse()

        if length(records) > limit do
          {tl(records), hd(records).reconciliation_id, List.last(records).reconciliation_id}
        else
          {records, nil, List.last(records) && List.last(records).reconciliation_id}
        end

      cursor_after ->
        records =
          query
          |> where([r], r.reconciliation_id < ^cursor_after)
          |> order_by([r], desc: r.reconciliation_id)
          |> limit(^(limit + 1))
          |> Nexus.Repo.all()

        if length(records) > limit do
          has_more_records = Enum.take(records, limit)

          {has_more_records, hd(has_more_records).reconciliation_id,
           List.last(records).reconciliation_id}
        else
          {records, hd(records) && hd(records).reconciliation_id, nil}
        end

      true ->
        records =
          query
          |> order_by([r], desc: r.reconciliation_id)
          |> limit(^(limit + 1))
          |> Nexus.Repo.all()

        if length(records) > limit do
          has_more_records = Enum.take(records, limit)
          {has_more_records, nil, List.last(records).reconciliation_id}
        else
          {records, nil, nil}
        end
    end
  end

  defp filter_items(items, "", _fields), do: items

  defp filter_items(items, query, fields) do
    query = String.downcase(query)

    Enum.filter(items, fn item ->
      Enum.any?(fields, fn field ->
        val = Map.get(item, field) |> to_string() |> String.downcase()
        String.contains?(val, query)
      end)
    end)
  end
end
