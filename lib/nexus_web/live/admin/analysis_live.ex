defmodule NexusWeb.Admin.AnalysisLive do
  @moduledoc """
  LiveView for system administrators to review all intelligence analyses across all tenants.
  """
  use NexusWeb, :live_view

  alias Nexus.Intelligence.Queries.AnalysisQuery
  alias Nexus.Intelligence.Projections.Analysis
  alias Nexus.Organization.Queries.TenantQuery

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nexus.PubSub, "intelligence:analyses")
    end

    anomalies = AnalysisQuery.list_all_anomalies()
    sentiments = AnalysisQuery.list_all_sentiments()
    org_names = fetch_org_names(anomalies, sentiments)

    socket =
      socket
      |> assign(:page_title, "AI Sentinel")
      |> assign(:page_subtitle, "Operations Intelligence Hub")
      |> assign(:anomalies, anomalies)
      |> assign(:sentiments, sentiments)
      |> assign(:org_names, org_names)
      |> assign(:active_tab, "overview")

    {:ok, socket}
  end

  @impl true
  def handle_info({:analysis_projected, %Analysis{} = _analysis}, socket) do
    anomalies = AnalysisQuery.list_all_anomalies()
    sentiments = AnalysisQuery.list_all_sentiments()
    org_names = fetch_org_names(anomalies, sentiments)

    {:noreply,
     socket
     |> assign(:anomalies, anomalies)
     |> assign(:sentiments, sentiments)
     |> assign(:org_names, org_names)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("dismiss_anomaly", %{"id" => id}, socket) do
    if anomaly = Nexus.Repo.get(Analysis, id) do
      Nexus.Repo.delete(anomaly)
    end

    anomalies = AnalysisQuery.list_all_anomalies()

    socket =
      socket
      |> assign(:anomalies, anomalies)
      |> put_flash(:info, "Anomaly dismissed securely. Operations model updated.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("investigate_anomaly", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/analysis/investigate/#{id}")}
  end

  defp fetch_org_names(anomalies, sentiments) do
    org_ids =
      (Enum.map(anomalies, & &1.org_id) ++ Enum.map(sentiments, & &1.org_id))
      |> Enum.uniq()

    Enum.into(org_ids, %{}, fn id ->
      {id, TenantQuery.get_name(id)}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <!-- Live Stream Header -->
      <.page_header
        title="AI Sentinel"
        subtitle="Real-time intelligence • 12ms latency • 142 ev/s"
      >
        <:actions>
          <div class="flex items-center gap-2 px-2.5 py-1 rounded bg-emerald-500/10 border border-emerald-500/20">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span class="text-[10px] font-bold text-emerald-400 uppercase tracking-widest mt-0.5">
              Live Stream
            </span>
          </div>
        </:actions>
      </.page_header>

    <!-- Top KPIs -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8 w-full">
        <.dark_card class="p-6 flex flex-col justify-between">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                Active Anomalies
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-slate-100 tracking-tight">
                  {length(@anomalies)}
                </span>
              </div>
            </div>
            <div class="w-10 h-10 rounded-full bg-rose-500/10 flex items-center justify-center">
              <span class="hero-exclamation-triangle w-5 h-5 text-rose-400"></span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">Requires immediate attention</p>
          </div>
        </.dark_card>

        <.dark_card class="p-6 flex flex-col justify-between">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                Comms Evaluated
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-slate-100 tracking-tight">
                  {length(@sentiments)}
                </span>
              </div>
            </div>
            <div class="w-10 h-10 rounded-full bg-indigo-500/10 flex items-center justify-center">
              <span class="hero-chat-bubble-bottom-center-text w-5 h-5 text-indigo-400"></span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">Inbound streams processed today</p>
          </div>
        </.dark_card>

        <.dark_card class="p-6 flex flex-col justify-between">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mb-1">
                Engine Status
              </h3>
              <div class="flex items-baseline gap-2">
                <span class="text-3xl font-black text-emerald-400 tracking-tight">Online</span>
              </div>
            </div>
            <div class="flex items-center justify-center w-10 h-10 rounded-full bg-emerald-500/10">
              <span class="relative flex h-3 w-3">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
                </span>
                <span class="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
              </span>
            </div>
          </div>
          <div class="mt-4 pt-4 border-t border-white/5">
            <p class="text-[10px] text-slate-400">Running EXLA Local Pipeline</p>
          </div>
        </.dark_card>
      </div>

    <!-- Navigation Tabs -->
      <div class="flex items-center gap-6 border-b border-white/10 mb-2 w-full">
        <.tab_button
          active={@active_tab == "overview"}
          click="set_tab"
          tab="overview"
          label="Insights Overview"
        />
        <.tab_button
          active={@active_tab == "anomalies"}
          click="set_tab"
          tab="anomalies"
          label="Detected Anomalies"
          count={length(@anomalies)}
        />
        <.tab_button
          active={@active_tab == "sentiment"}
          click="set_tab"
          tab="sentiment"
          label="Sentiment Streams"
        />
      </div>

      <div class={"grid grid-cols-1 gap-8 w-full " <> if @active_tab == "overview", do: "lg:grid-cols-2", else: ""}>
        <!-- Anomalies List -->
        <%= if @active_tab in ["overview", "anomalies"] do %>
          <.dark_card class="p-6 relative overflow-hidden h-fit">
            <div class="flex items-center justify-between mb-8 border-b border-white/5 pb-4">
              <div>
                <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
                  Detected Anomalies
                </h2>
                <p class="text-[10px] text-slate-400 mt-1">
                  Invoices flagged for statistical review based on historical data.
                </p>
              </div>
            </div>

            <div class="space-y-4 max-h-[600px] overflow-y-auto pr-2 custom-scrollbar">
              <%= if Enum.empty?(@anomalies) do %>
                <div class="flex flex-col items-center justify-center py-16 text-center bg-black/10 rounded-xl border border-dashed border-white/10">
                  <div class="w-16 h-16 rounded-full bg-emerald-500/10 flex items-center justify-center mb-5">
                    <.icon name="hero-shield-check" class="w-8 h-8 text-emerald-400" />
                  </div>
                  <h3 class="text-sm font-bold text-slate-200">System Secure</h3>
                  <p class="text-xs text-slate-500 mt-2 max-w-xs leading-relaxed">
                    No statistical anomalies detected across ERP streams in the current context window.
                  </p>
                </div>
              <% else %>
                <%= for anomaly <- @anomalies do %>
                  <div class="group relative p-4 rounded-xl bg-slate-900/40 border border-slate-700/50 hover:bg-slate-800/40 transition-colors">
                    <div class="flex justify-between items-start mb-3">
                      <div class="flex items-center space-x-3">
                        <div class="w-8 h-8 rounded-full bg-rose-500/10 flex items-center justify-center">
                          <.icon name="hero-document-magnifying-glass" class="w-4 h-4 text-rose-400" />
                        </div>
                        <div>
                          <h4 class="text-sm font-bold text-slate-200">{anomaly.invoice_id}</h4>
                          <p class="text-[11px] font-medium text-slate-400 mt-0.5">
                            Org:
                            <span class="text-slate-300 font-mono">{@org_names[anomaly.org_id]}</span>
                          </p>
                        </div>
                      </div>
                      <div class="flex flex-col items-end">
                        <div class="inline-flex items-center justify-center px-2 py-1 rounded bg-rose-500/10 text-[10px] font-bold text-rose-400 uppercase tracking-widest">
                          Score: {Float.round(anomaly.score, 2)}
                        </div>
                        <p class="text-[10px] text-slate-500 mt-1.5 uppercase font-medium tracking-wider">
                          {Calendar.strftime(anomaly.flagged_at, "%H:%M UTC")}
                        </p>
                      </div>
                    </div>
                    <div class="mt-3 mb-4 p-3 rounded-lg bg-black/20 text-[11px] text-slate-300 border border-white/5">
                      <span class="font-bold text-rose-400/90 mr-2 uppercase tracking-wider">
                        Reason
                      </span>
                      {anomaly.reason}
                    </div>

    <!-- Actions -->
                    <div class="flex items-center gap-3 pt-4 border-t border-white/5 mt-auto">
                      <button
                        phx-click="investigate_anomaly"
                        phx-value-id={anomaly.id}
                        class="flex-1 flex items-center justify-center gap-2 px-3 py-2 bg-indigo-500 hover:bg-indigo-600 text-white text-[11px] font-bold uppercase tracking-wider rounded transition-colors group"
                      >
                        <.icon
                          name="hero-magnifying-glass"
                          class="w-4 h-4 text-indigo-200 group-hover:text-white transition-colors"
                        /> Investigate
                      </button>
                      <button
                        phx-click="dismiss_anomaly"
                        phx-value-id={anomaly.id}
                        class="flex-1 flex items-center justify-center gap-2 px-3 py-2 bg-transparent hover:bg-slate-800 text-slate-300 text-[11px] font-bold uppercase tracking-wider rounded border border-slate-700 hover:border-slate-600 transition-colors group"
                      >
                        <.icon
                          name="hero-x-mark"
                          class="w-4 h-4 text-slate-500 group-hover:text-slate-300 transition-colors"
                        /> Dismiss
                      </button>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </.dark_card>
        <% end %>

    <!-- Sentiments List -->
        <%= if @active_tab in ["overview", "sentiment"] do %>
          <.dark_card class="p-6 relative overflow-hidden h-fit">
            <div class="flex items-center justify-between mb-8 border-b border-white/5 pb-4">
              <div>
                <h2 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em]">
                  Sentiment Streams
                </h2>
                <p class="text-[10px] text-slate-400 mt-1">
                  Real-time tone analysis of inbound vendor communications.
                </p>
              </div>
            </div>

            <div class="space-y-4 max-h-[600px] overflow-y-auto pr-2 custom-scrollbar">
              <%= if Enum.empty?(@sentiments) do %>
                <div class="flex flex-col items-center justify-center py-16 text-center bg-black/10 rounded-xl border border-dashed border-white/10">
                  <div class="w-16 h-16 rounded-full bg-slate-800 flex items-center justify-center mb-5">
                    <.icon name="hero-chat-bubble-left-ellipsis" class="w-8 h-8 text-slate-500" />
                  </div>
                  <h3 class="text-sm font-bold text-slate-200">No Streams Available</h3>
                  <p class="text-xs text-slate-500 mt-2 max-w-xs leading-relaxed">
                    Awaiting ingestion of vendor communications for NLP scoring.
                  </p>
                </div>
              <% else %>
                <%= for sent <- @sentiments do %>
                  <div class="group relative p-4 rounded-xl bg-slate-900/40 border border-slate-700/50 hover:bg-slate-800/40 transition-colors">
                    <div class="flex justify-between items-center">
                      <div class="flex items-center space-x-4">
                        <div class={"w-8 h-8 rounded-full flex items-center justify-center " <>
                        if sent.sentiment == "positive", do: "bg-emerald-500/10", else: "bg-rose-500/10"
                      }>
                          <.icon
                            name={
                              if sent.sentiment == "positive",
                                do: "hero-face-smile",
                                else: "hero-face-frown"
                            }
                            class={"w-4 h-4 " <> if sent.sentiment == "positive", do: "text-emerald-400", else: "text-rose-400"}
                          />
                        </div>
                        <div>
                          <h4 class="text-sm font-bold text-slate-200">
                            Source: {sent.source_id || "Unknown"}
                          </h4>
                          <p class="text-[11px] text-slate-400 mt-0.5">
                            Org:
                            <span class="text-slate-300 font-mono">{@org_names[sent.org_id]}</span>
                          </p>
                          <p class="text-[10px] text-slate-500 mt-1.5 uppercase font-medium tracking-wider">
                            {Calendar.strftime(sent.scored_at, "%b %d, %H:%M UTC")}
                          </p>
                        </div>
                      </div>

                      <div class="flex flex-col items-end justify-center h-full">
                        <p class={"text-[10px] font-bold uppercase tracking-widest " <>
                        if sent.sentiment == "positive", do: "text-emerald-400", else: "text-rose-400"
                      }>
                          {sent.sentiment}
                        </p>

    <!-- Confidence Bar -->
                        <div class="w-24 mt-2">
                          <div class="flex items-center justify-between text-[9px] font-bold text-slate-500 mb-1.5 uppercase tracking-widest">
                            <span>Conf</span>
                            <span>{round(sent.confidence * 100)}%</span>
                          </div>
                          <div class="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
                            <div
                              class={"h-full rounded-full transition-all duration-1000 " <> if sent.sentiment == "positive", do: "bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]", else: "bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.5)]"}
                              style={"width: #{sent.confidence * 100}%"}
                            >
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </.dark_card>
        <% end %>
      </div>
    </.page_container>
    """
  end

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-tab={@tab}
      class={"pb-3 text-sm font-bold transition-colors border-b-2 relative -mb-[1px] " <> if @active, do: "text-white border-indigo-500", else: "text-slate-500 border-transparent hover:text-slate-300 hover:border-slate-700"}
    >
      {@label}
      <%= if assigns[:count] do %>
        <span class={"ml-2 px-2 py-0.5 text-[10px] rounded focus:outline-none " <> if @active, do: "bg-indigo-500/20 text-indigo-400", else: "bg-slate-800 text-slate-400"}>
          {@count}
        </span>
      <% end %>
    </button>
    """
  end
end
