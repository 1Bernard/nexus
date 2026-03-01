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
    end

    {:ok,
     socket
     |> assign(:selected_invoice_id, nil)
     |> assign(:selected_line_id, nil)
     |> assign(:invoice_search, "")
     |> assign(:line_search, "")
     |> assign(:variance_reason, nil)
     |> assign(:filter_date_from, "")
     |> assign(:filter_date_to, "")
     |> assign(:filter_type, "all")
     |> load_data()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    type = params["type"] || "all"

    {:noreply,
     socket
     |> assign(:page_title, "Match Engine")
     |> assign(:filter_type, type)
     |> load_data()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-6 w-full px-4 md:px-6 pb-12">
      <div class="flex items-center justify-between mb-2">
        <div>
          <h1 class="text-3xl font-serif italic font-bold text-white tracking-tight">
            Match Engine
          </h1>
          <p class="text-slate-500 text-sm mt-1">Cross-system reconciliation & anomaly detection</p>
        </div>
        <div class="flex items-center gap-3">
          <.dark_card class="px-4 py-2 flex items-center gap-4 bg-emerald-500/5 border-emerald-500/10">
            <div class="flex flex-col">
              <span class="text-[9px] uppercase tracking-widest text-slate-500 font-bold">
                Auto-Match Status
              </span>
              <span class="text-xs text-emerald-400 font-black uppercase tracking-tight">
                Active & Optimizing
              </span>
            </div>
            <div class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></div>
          </.dark_card>
        </div>
      </div>

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

      <.dark_card class="p-0 flex flex-col">
        <div class="p-6 border-b border-white/5 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <span class="hero-list-bullet w-4 h-4 text-emerald-400"></span>
            </div>
            <h2 class="text-xs font-bold text-slate-300 uppercase tracking-[0.2em]">
              Matched Ledger (Audit Trail)
            </h2>
          </div>
          <div class="flex items-center gap-4">
            <form
              phx-change="filter_ledger"
              class="flex items-center gap-3 mr-2 border-r border-white/5 pr-4"
            >
              <input
                type="date"
                name="date_from"
                value={@filter_date_from}
                class="bg-black/20 border border-white/10 rounded px-2 py-1 text-xs text-slate-300 w-[120px]"
              />
              <span class="text-slate-500 text-xs">-</span>
              <input
                type="date"
                name="date_to"
                value={@filter_date_to}
                class="bg-black/20 border border-white/10 rounded px-2 py-1 text-xs text-slate-300 w-[120px]"
              />
              <select
                name="type"
                class="bg-black/20 border border-white/10 rounded px-2 py-1 text-xs text-slate-300"
              >
                <option value="all" selected={@filter_type == "all"}>All Types</option>
                <option value="auto" selected={@filter_type == "auto"}>Auto</option>
                <option value="manual" selected={@filter_type == "manual"}>Manual</option>
                <option value="pending" selected={@filter_type == "pending"}>Pending</option>
                <option value="rejected" selected={@filter_type == "rejected"}>Rejected</option>
              </select>
            </form>
            <div class="flex items-center gap-1.5 text-[9px] text-slate-500 uppercase tracking-widest font-bold border-r border-white/5 pr-4 mr-2">
              <span class="hero-check-badge w-3.5 h-3.5 text-emerald-500"></span> Verified
            </div>
            <button
              phx-click="export_csv"
              class="text-[10px] font-bold text-indigo-400 hover:text-indigo-300 transition-colors uppercase tracking-widest flex items-center gap-1.5"
            >
              <span class="hero-arrow-down-tray w-3.5 h-3.5"></span> Export CSV
            </button>
          </div>
        </div>

        <div class="overflow-x-auto scroll-soft">
          <table class="w-full text-left border-collapse table-fixed min-w-[900px]">
            <thead>
              <tr class="border-b border-white/5 bg-white/[0.01]">
                <th class="p-4 w-12"></th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest w-32">
                  Match Type
                </th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                  References (SAP / Bank)
                </th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">
                  Matched
                </th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">
                  Variance
                </th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                  Timestamp
                </th>
                <th class="p-4 text-[10px] font-bold text-slate-500 uppercase tracking-widest text-right">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-white/[0.03]">
              <%= for recon <- @reconciliations do %>
                <tr class="group hover:bg-white/[0.02] transition-colors relative">
                  <td class="p-4 text-center">
                    <span class="hero-lock-closed w-3.5 h-3.5 text-slate-700"></span>
                  </td>
                  <td class="p-4">
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
                        <span class="text-[9px] font-bold text-slate-400 uppercase tracking-wider">
                          Auto
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="p-4">
                    <div class="flex flex-col gap-0.5">
                      <div class="flex items-center gap-2">
                        <span class="text-[10px] font-mono text-indigo-400">SAP:</span>
                        <span class="text-xs font-bold text-slate-300">#{recon.invoice_id}</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <span class="text-[10px] font-mono text-amber-400">BNK:</span>
                        <span class="text-[11px] text-slate-500 font-medium truncate max-w-[150px]">
                          #{recon.statement_line_id}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td class="p-4 text-right">
                    <span class="text-xs font-mono font-bold text-white">
                      {recon.amount} {recon.currency}
                    </span>
                  </td>
                  <td class="p-4 text-right">
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
                  </td>
                  <td class="p-4">
                    <div class="flex flex-col items-start gap-1">
                      <span class="text-[10px] text-slate-300 font-bold">
                        {Calendar.strftime(recon.matched_at, "%d %b %Y")}
                      </span>
                      <span class="text-[9px] text-slate-500 uppercase tracking-widest font-mono">
                        {Calendar.strftime(recon.matched_at, "%H:%M:%S UTC")}
                      </span>
                    </div>
                  </td>
                  <td class="p-4 text-right">
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
                  </td>
                </tr>
              <% end %>
              <%= if Enum.empty?(@reconciliations) do %>
                <tr>
                  <td colspan="6" class="p-20 text-center opacity-20">
                    <div class="flex flex-col items-center">
                      <span class="hero-archive-box w-12 h-12 mb-4"></span>
                      <p class="text-xs uppercase tracking-[0.2em] font-bold italic">
                        Secured Audit Ledger Empty
                      </p>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </.dark_card>
    </div>
    """
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, load_data(socket)}
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
    {:noreply, socket |> assign(:invoice_search, query) |> load_data()}
  end

  @impl true
  def handle_event("search_lines", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:line_search, query) |> load_data()}
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
         |> load_data()}

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
         |> load_data()}

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
         |> load_data()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to reject match.")}
    end
  end

  defp load_data(socket) do
    org_id = socket.assigns.current_user.org_id

    invoices =
      Treasury.list_unmatched_invoices(org_id)
      |> filter_items(socket.assigns.invoice_search, [:sap_document_number, :subsidiary, :amount])

    lines =
      Treasury.list_unmatched_statement_lines(org_id)
      |> filter_items(socket.assigns.line_search, [:ref, :narrative, :amount])

    all_reconciliations = Treasury.list_reconciliations(org_id)

    filtered_reconciliations =
      all_reconciliations
      |> filter_by_date(socket.assigns.filter_date_from, socket.assigns.filter_date_to)
      |> filter_by_type(socket.assigns.filter_type)

    socket
    |> assign(:unmatched_invoices, invoices)
    |> assign(:unmatched_lines, lines)
    |> assign(:reconciliations, filtered_reconciliations)
  end

  defp filter_by_date(reconciliations, "", ""), do: reconciliations

  defp filter_by_date(reconciliations, from, to) do
    Enum.filter(reconciliations, fn r ->
      date_str = Calendar.strftime(r.matched_at, "%Y-%m-%d")
      passes_from = if from == "", do: true, else: date_str >= from
      passes_to = if to == "", do: true, else: date_str <= to
      passes_from and passes_to
    end)
  end

  defp filter_by_type(reconciliations, "all"), do: reconciliations

  defp filter_by_type(reconciliations, type) do
    Enum.filter(reconciliations, fn r ->
      is_manual =
        String.contains?(r.reconciliation_id, "MANUAL") or
          String.split(r.reconciliation_id, "-") |> Enum.at(0) |> String.length() > 30

      case type do
        "manual" -> is_manual
        "auto" -> not is_manual
        "pending" -> r.status == :pending
        "rejected" -> r.status == :rejected
        _ -> true
      end
    end)
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
