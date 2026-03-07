defmodule NexusWeb.Admin.AnomalyInvestigationLive do
  @moduledoc """
  LiveView for system administrators to investigate and resolve detected anomalies.
  """
  use NexusWeb, :live_view

  alias Nexus.Intelligence.Queries.AnalysisQuery
  alias Nexus.Intelligence.Commands.ResolveAnomaly
  alias Nexus.Organization.Queries.TenantQuery

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    anomaly = AnalysisQuery.get_anomaly!(id)
    org_name = TenantQuery.get_name(anomaly.org_id)

    # Simulating fetching raw invoice data from ERP
    raw_invoice =
      if anomaly.invoice_id do
        %{
          id: anomaly.invoice_id,
          vendor: "Acme Corp (Simulated)",
          total_amount: "€12,500.00",
          line_items: [
            %{desc: "Cloud Infrastructure (High Priority)", qty: 1, price: "€8,500.00"},
            %{desc: "Support Premium Tier", qty: 1, price: "€4,000.00"},
            # The anomaly!
            %{desc: "Enterprise Support SLA (Overage)", qty: 1, price: "€2,500.00"}
          ]
        }
      else
        nil
      end

    socket =
      socket
      |> assign(:page_title, "Forensic Investigation")
      |> assign(:page_subtitle, "Anomaly ID: #{String.slice(id, 0, 8)}")
      |> assign(:anomaly, anomaly)
      |> assign(:org_name, org_name)
      |> assign(:raw_invoice, raw_invoice)

    {:ok, socket}
  end

  @impl true
  def handle_event("resolve", %{"resolution" => resolution}, socket) do
    command = %ResolveAnomaly{
      analysis_id: socket.assigns.anomaly.id,
      org_id: socket.assigns.anomaly.org_id,
      resolution: resolution,
      resolved_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(command) do
      :ok ->
        msg =
          if resolution == "fraud",
            do: "Invoice marked as fraudulent. Operations and Audit notified.",
            else: "Anomaly mathematically cleared. Processing resumed."

        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> push_navigate(to: ~p"/admin/analysis")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Resolution dispatch failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <.page_header title={@page_title} subtitle={@page_subtitle}>
        <:actions>
          <.link
            navigate={~p"/admin/analysis"}
            class="flex items-center gap-2 text-xs font-bold text-slate-400 hover:text-white transition-colors uppercase tracking-widest"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Sentinel
          </.link>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Left Pane: ML Statistics & Reason -->
        <div class="space-y-6">
          <.dark_card class="p-8 border-rose-500/20 shadow-[0_0_30px_rgba(244,63,94,0.05)]">
            <div class="flex items-center justify-between mb-8">
              <h2 class="text-sm font-bold text-rose-400 uppercase tracking-widest flex items-center gap-3">
                <.icon name="hero-cpu-chip" class="w-5 h-5" /> Inference Engine Output
              </h2>
              <div class="px-3 py-1 bg-rose-500/10 rounded border border-rose-500/20 text-rose-400 text-xs font-mono font-bold">
                SCORE: {Float.round(@anomaly.score * 100, 1)}%
              </div>
            </div>

            <div class="space-y-6">
              <div>
                <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2">
                  Detection Reason
                </label>
                <div class="p-4 bg-black/40 rounded-xl border border-white/5 text-slate-300 text-sm leading-relaxed font-mono">
                  {@anomaly.reason}
                </div>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div class="p-4 bg-slate-900/50 rounded-xl border border-white/5">
                  <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
                    Organization
                  </label>
                  <span class="text-slate-300 text-xs font-mono">{@org_name}</span>
                </div>
                <div class="p-4 bg-slate-900/50 rounded-xl border border-white/5">
                  <label class="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1">
                    Flagged At
                  </label>
                  <span class="text-slate-300 text-xs font-mono">
                    {Calendar.strftime(@anomaly.flagged_at, "%Y-%m-%d %H:%M:%S UTC")}
                  </span>
                </div>
              </div>
            </div>
          </.dark_card>

    <!-- Resolution Actions -->
          <.dark_card class="p-8">
            <h3 class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-6 border-b border-white/5 pb-4">
              Required Action
            </h3>
            <div class="flex gap-4">
              <button
                phx-click="resolve"
                phx-value-resolution="cleared"
                class="flex-1 flex flex-col items-center justify-center gap-2 p-4 bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/20 hover:border-emerald-500/50 rounded-xl transition-all group"
              >
                <.icon
                  name="hero-check-circle"
                  class="w-8 h-8 text-emerald-500 group-hover:scale-110 transition-transform"
                />
                <span class="text-xs font-bold text-emerald-400 uppercase tracking-widest mt-2">
                  Clear Anomaly
                </span>
                <span class="text-[10px] text-emerald-500/70 text-center px-4">
                  Mathematical deviation justified. Approve for payment flow.
                </span>
              </button>

              <button
                phx-click="resolve"
                phx-value-resolution="fraud"
                class="flex-1 flex flex-col items-center justify-center gap-2 p-4 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/20 hover:border-rose-500/50 rounded-xl transition-all group"
              >
                <.icon
                  name="hero-shield-exclamation"
                  class="w-8 h-8 text-rose-500 group-hover:scale-110 transition-transform"
                />
                <span class="text-xs font-bold text-rose-400 uppercase tracking-widest mt-2">
                  Mark as Fraud
                </span>
                <span class="text-[10px] text-rose-500/70 text-center px-4">
                  Suspend payment and alert audit continuity team immediately.
                </span>
              </button>
            </div>
          </.dark_card>
        </div>

    <!-- Right Pane: Raw Invoice Data -->
        <div>
          <.dark_card class="p-0 h-full flex flex-col">
            <div class="p-8 border-b border-white/5">
              <h2 class="text-sm font-bold text-slate-300 uppercase tracking-widest flex items-center gap-3">
                <.icon name="hero-document-text" class="w-5 h-5 text-slate-500" />
                Source Invoice Context
              </h2>
            </div>

            <div class="p-8 flex-1">
              <%= if @raw_invoice do %>
                <div class="flex justify-between items-start mb-10">
                  <div>
                    <h1 class="text-2xl font-black text-white tracking-tight">
                      {@raw_invoice.vendor}
                    </h1>
                    <p class="text-slate-500 font-mono text-xs mt-1">ID: {@raw_invoice.id}</p>
                  </div>
                  <div class="text-right">
                    <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-1">
                      Total
                    </p>
                    <p class="text-2xl font-black text-rose-400">{@raw_invoice.total_amount}</p>
                  </div>
                </div>

                <div class="space-y-1 mb-8">
                  <div class="flex justify-between text-xs font-bold text-slate-500 uppercase tracking-widest pb-3 border-b border-white/5 mb-3">
                    <span>Description</span>
                    <span>Amount</span>
                  </div>
                  <%= for item <- @raw_invoice.line_items do %>
                    <div class="flex justify-between py-3 border-b border-white/5 text-sm">
                      <span class={"font-medium " <> if String.contains?(item.desc, "Overage"), do: "text-rose-400 font-bold", else: "text-slate-300"}>
                        {item.desc}
                      </span>
                      <span class={"font-mono " <> if String.contains?(item.desc, "Overage"), do: "text-rose-400 font-bold", else: "text-slate-400"}>
                        {item.price}
                      </span>
                    </div>
                  <% end %>
                </div>

                <div class="p-4 bg-indigo-500/5 rounded border border-indigo-500/10 flex gap-4 mt-auto">
                  <.icon name="hero-information-circle" class="w-5 h-5 text-indigo-400 shrink-0" />
                  <p class="text-xs text-indigo-200/70 leading-relaxed">
                    The ML model flagged the "Overage" line item because it diverges from the 90-day historical billing pattern for this vendor by more than 3 standard deviations.
                  </p>
                </div>
              <% else %>
                <div class="flex flex-col items-center justify-center py-20 text-center space-y-4 opacity-50 h-full">
                  <.icon name="hero-no-symbol" class="w-12 h-12 text-slate-600" />
                  <p class="text-sm text-slate-500 uppercase tracking-widest font-bold">
                    No Source Invoice Linked
                  </p>
                  <p class="text-xs text-slate-600 max-w-[240px]">
                    This anomaly was detected via an external data stream (e.g., API webhook) without a primary invoice reference.
                  </p>
                </div>
              <% end %>
            </div>
          </.dark_card>
        </div>
      </div>
    </.page_container>
    """
  end
end
