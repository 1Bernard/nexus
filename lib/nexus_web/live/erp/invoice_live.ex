defmodule NexusWeb.ERP.InvoiceLive do
  use NexusWeb, :live_view

  alias Nexus.ERP.Projections.Invoice
  alias Nexus.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # In a real app we would subscribe to pubsub for realtime updates here
    end

    org_id = socket.assigns.current_user.org_id

    invoices =
      Invoice
      |> where([i], i.org_id == ^org_id)
      |> order_by([i], desc: i.created_at)
      |> limit(50)
      |> Repo.all()

    {:ok, assign(socket, invoices: invoices, page_title: "ERP Ingestion Engine")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-10 max-w-7xl mx-auto mt-16">
      <div class="mb-8 hidden">
        <%!-- Used by test or navigation --%>
      </div>
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-zinc-100">ERP Talk Back</h1>
          <p class="text-zinc-400 mt-2">Real-time SAP webhook ingestion feed.</p>
        </div>
        <div class="flex gap-3">
          <div class="px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm rounded-full flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> System Online
          </div>
        </div>
      </div>

      <div class="grid gap-4">
        <%= for invoice <- @invoices do %>
          <div class="p-6 bg-zinc-900 border border-emerald-500/20 rounded-xl shadow-[0_0_15px_rgba(16,185,129,0.05)] flex items-center justify-between">
            <div>
              <div class="flex items-center gap-3 mb-1">
                <span class="text-emerald-400 font-mono text-sm px-2 py-0.5 bg-emerald-500/10 rounded">
                  {invoice.sap_document_number}
                </span>
                <span class="text-zinc-500 text-sm">
                  {invoice.created_at |> Calendar.strftime("%Y-%m-%d %H:%M:%S")}
                </span>
              </div>
              <div class="text-lg font-medium text-zinc-100">
                {invoice.entity_id} &middot; {invoice.subsidiary}
              </div>
            </div>
            <div class="text-right">
              <div class="text-2xl font-semibold text-emerald-400">
                {invoice.amount} {invoice.currency}
              </div>
              <div class="text-sm text-zinc-500">
                {length(invoice.line_items || [])} Line Items
              </div>
            </div>
          </div>
        <% end %>

        <%= if Enum.empty?(@invoices) do %>
          <div class="p-12 text-center border border-dashed border-zinc-800 rounded-xl">
            <svg
              class="w-12 h-12 mx-auto text-zinc-600 mb-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
              />
            </svg>
            <h3 class="text-zinc-300 font-medium">No Invoices Ingested</h3>
            <p class="text-zinc-500 mt-1">Waiting for SAP webhook connectivity...</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
