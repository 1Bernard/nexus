defmodule NexusWeb.Tenant.AnalysisLive do
  use NexusWeb, :live_view

  alias Nexus.Intelligence.Queries.AnalysisQuery
  alias Nexus.Intelligence.Projections.Analysis

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "intelligence:analyses")
    end

    org_id = socket.assigns.current_user.org_id

    anomalies = AnalysisQuery.list_anomalies(org_id)
    sentiments = AnalysisQuery.list_sentiments(org_id)

    {:ok,
     socket
     |> assign(:page_title, "Smart Insights")
     |> assign(:page_subtitle, "AI-Powered Intelligence")
     |> assign(:anomalies, anomalies)
     |> assign(:sentiments, sentiments)
     |> assign(:active_tab, :anomalies)}
  end

  @impl true
  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("investigate", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Investigating anomaly ID: #{String.slice(id, 0, 8)}...")}
  end

  @impl true
  def handle_info({:analysis_projected, %Analysis{} = _analysis}, socket) do
    org_id = socket.assigns.current_user.org_id
    anomalies = AnalysisQuery.list_anomalies(org_id)
    sentiments = AnalysisQuery.list_sentiments(org_id)

    {:noreply,
     socket
     |> assign(:anomalies, anomalies)
     |> assign(:sentiments, sentiments)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container>
      <.page_header title="Smart Insights" subtitle="AI-Powered Intelligence">
        <:actions>
          <div class="px-4 py-2 bg-slate-900/50 border border-white/5 rounded-xl text-right">
            <span class="block text-[10px] uppercase tracking-widest text-slate-500 font-bold mb-0.5">
              Protocol Status
            </span>
            <span class="text-xs font-mono text-emerald-400">NOMINAL // AUTO-SCALE</span>
          </div>
        </:actions>
      </.page_header>

      <%!-- Intelligence Protocol Banner --%>
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-6 p-8 bg-indigo-500/5 border border-indigo-500/10 rounded-3xl backdrop-blur-sm relative overflow-hidden group">
        <div class="absolute -right-20 -top-20 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl group-hover:bg-indigo-500/15 transition-all duration-700">
        </div>

        <div class="relative z-10 flex items-center gap-5">
          <div class="w-16 h-16 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
            <span class="hero-sparkles w-8 h-8 animate-pulse"></span>
          </div>
          <div>
            <h2 class="text-2xl font-bold tracking-tight text-white">Sentinel Ingestion Active</h2>
            <p class="text-slate-500 text-sm mt-1">
              Scanning <span class="text-indigo-400 font-mono">Real-Time</span>
              ERP and Comms streams • 99.8% Confidence
            </p>
          </div>
        </div>

      </div>

      <%!-- Dashboard Stats --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.stat_card
          label="Active Anomalies"
          value={"#{length(@anomalies)}"}
          change="Flagged today"
          trend={if length(@anomalies) > 0, do: "up", else: nil}
          icon="hero-exclamation-triangle"
        />
        <.stat_card
          label="Sentiment Average"
          value="8.4"
          change="Stable Trend"
          trend="up"
          icon="hero-face-smile"
        />
        <.stat_card
          label="Inference Latency"
          value="42ms"
          change="-12% vs last hour"
          trend="down"
          icon="hero-bolt"
        />
      </div>

      <%!-- Content Segmentation --%>
      <.dark_card>
        <nav class="flex border-b border-white/5 p-2">
          <button
            phx-click="select-tab"
            phx-value-tab="anomalies"
            class={[
              "flex-1 py-4 text-[10px] font-bold uppercase tracking-[0.2em] transition-all rounded-xl flex items-center justify-center gap-3",
              @active_tab == :anomalies && "bg-white/5 text-white shadow-inner",
              @active_tab != :anomalies && "text-slate-500 hover:text-slate-300 hover:bg-white/[0.02]"
            ]}
          >
            <span class="hero-magnifying-glass w-4 h-4"></span> Detected Anomalies
          </button>
          <button
            phx-click="select-tab"
            phx-value-tab="sentiments"
            class={[
              "flex-1 py-4 text-[10px] font-bold uppercase tracking-[0.2em] transition-all rounded-xl flex items-center justify-center gap-3",
              @active_tab == :sentiments && "bg-white/5 text-white shadow-inner",
              @active_tab != :sentiments &&
                "text-slate-500 hover:text-slate-300 hover:bg-white/[0.02]"
            ]}
          >
            <span class="hero-chat-bubble-left-ellipsis w-4 h-4"></span> Sentiment Insights
          </button>
        </nav>

        <div class="p-6">
          <%= if @active_tab == :anomalies do %>
            <div class="space-y-4">
              <%= if Enum.empty?(@anomalies) do %>
                <.empty_state
                  icon="hero-shield-check"
                  title="No anomalies detected"
                  message="Scanning ERP streams... System integrity is currently verified."
                />
              <% else %>
                <%= for anomaly <- @anomalies do %>
                  <div class="group bg-slate-900/40 border border-white/5 p-5 rounded-2xl hover:bg-slate-800/40 transition-all flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div class="flex items-center gap-5">
                      <div class={[
                        "w-12 h-12 rounded-xl border flex items-center justify-center group-hover:scale-105 transition-transform",
                        anomaly.invoice_id && "bg-rose-500/10 border-rose-500/20 text-rose-400",
                        !anomaly.invoice_id && "bg-amber-500/10 border-amber-500/20 text-amber-400"
                      ]}>
                        <span class={
                          if anomaly.invoice_id,
                            do: "hero-document-magnifying-glass w-6 h-6",
                            else: "hero-exclamation-triangle w-6 h-6"
                        }>
                        </span>
                      </div>
                      <div>
                        <h3 class="font-bold text-slate-200">
                          {if anomaly.invoice_id,
                            do: "High Risk Deviation",
                            else: "Reconciliation Alert"}
                        </h3>
                        <p class="text-slate-500 text-xs mt-1 leading-relaxed max-w-md">
                          {anomaly.reason}
                        </p>
                        <div class="flex items-center gap-3 mt-3">
                          <.badge variant="neutral" label={"REF: #{String.slice(anomaly.id, 0, 8)}"} />
                          <%= if anomaly.invoice_id do %>
                            <.badge
                              variant="danger"
                              label={"Risk Score: #{Float.round(anomaly.score * 100)}%"}
                            />
                          <% else %>
                            <.badge variant="warning" label="Unmatched Line" />
                          <% end %>
                        </div>
                      </div>
                    </div>
                    <div class="flex flex-row md:flex-col items-center md:items-end justify-between gap-3">
                      <span class="text-[10px] font-mono text-slate-600 uppercase tracking-widest font-bold">
                        {Calendar.strftime(anomaly.flagged_at, "%H:%M:%S UTC")}
                      </span>
                      <.nx_button
                        size="sm"
                        variant="primary"
                        phx-click="investigate"
                        phx-value-id={anomaly.id}
                      >
                        Investigate
                      </.nx_button>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <%= if Enum.empty?(@sentiments) do %>
                <div class="col-span-full">
                  <.empty_state
                    icon="hero-chat-bubble-bottom-center-text"
                    title="Awaiting analysis"
                    message="Ingest vendor comms to trigger NLP scoring."
                  />
                </div>
              <% else %>
                <%= for sentiment <- @sentiments do %>
                  <.dark_card class="p-6 relative overflow-hidden group">
                    <div class="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-indigo-500/5 to-transparent group-hover:scale-110 transition-transform duration-700">
                    </div>

                    <div class="flex items-start justify-between mb-5 relative z-10">
                      <.badge
                        variant={
                          cond do
                            sentiment.sentiment == "positive" -> "success"
                            sentiment.sentiment == "negative" -> "danger"
                            true -> "neutral"
                          end
                        }
                        label={String.upcase(sentiment.sentiment)}
                      />
                      <span class="text-[10px] font-mono text-slate-600 font-bold uppercase tracking-widest">
                        {Calendar.strftime(sentiment.scored_at, "%b %d, %H:%M")}
                      </span>
                    </div>

                    <p class="text-sm font-medium text-slate-300 leading-snug mb-6 relative z-10">
                      "Communication pattern aligns with historical trajectory. No immediate escalation needed."
                    </p>

                    <div class="pt-5 border-t border-white/5 relative z-10">
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                          Inference Confidence
                        </span>
                        <span class="text-[10px] font-mono font-bold text-slate-400">
                          {Float.round(sentiment.confidence * 100, 1)}%
                        </span>
                      </div>
                      <div class="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                        <div
                          class="h-full bg-indigo-500 shadow-[0_0_8px_rgba(99,102,241,0.5)] transition-all duration-1000"
                          style={"width: #{sentiment.confidence * 100}%"}
                        >
                        </div>
                      </div>
                    </div>
                  </.dark_card>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      </.dark_card>
    </.page_container>
    """
  end
end
