defmodule NexusWeb.DashboardLive do
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Institutional Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.dark_page class="p-8">
      <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <header class="flex justify-between items-center mb-12 border-b border-white/[0.06] pb-8">
          <div>
            <h1 class="text-3xl font-bold tracking-tight text-white mb-1">Institutional Dashboard</h1>
            <p class="text-slate-400 text-sm">Secure Terminal: 0xFD2BE...E48</p>
          </div>
          <div class="flex items-center gap-4">
            <div class="px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 rounded-full flex items-center gap-2">
              <div class="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse"></div>
              <span class="text-[10px] font-bold text-emerald-400 uppercase tracking-widest">
                Biometric Verified
              </span>
            </div>
            <div class="w-10 h-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center">
              <span class="hero-user w-5 h-5 text-slate-400"></span>
            </div>
          </div>
        </header>
        
    <!-- Grid Layout -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- Main Activity -->
          <div class="md:col-span-2 space-y-6">
            <.dark_card class="p-8 min-h-[400px] relative overflow-hidden group">
              <div class="absolute top-0 right-0 p-8 opacity-20 group-hover:opacity-40 transition-opacity">
                <span class="hero-chart-bar w-32 h-32"></span>
              </div>
              <h2 class="text-xl font-semibold mb-6">Market Activity</h2>
              <div class="flex flex-col items-center justify-center h-64 border-2 border-dashed border-white/5 rounded-3xl">
                <span class="hero-cube-transparent w-12 h-12 text-slate-600 mb-4 animate-bounce">
                </span>
                <p class="text-slate-500 text-sm font-mono">Initializing Neural Engine...</p>
              </div>
            </.dark_card>
          </div>
          
    <!-- Sidebar -->
          <div class="space-y-6">
            <.dark_card class="rounded-[2.2rem] p-6">
              <h3 class="text-xs font-bold text-slate-500 uppercase tracking-[0.2em] mb-4">Assets</h3>
              <div class="space-y-4">
                <.asset_item name="BTC/USD" price="68,432.12" change="+2.4%" />
                <.asset_item name="ETH/USD" price="3,491.08" change="+1.2%" />
                <.asset_item name="SOL/USD" price="142.19" change="-0.8%" />
              </div>
            </.dark_card>

            <div class="bg-indigo-600/10 border border-indigo-500/20 rounded-[2.2rem] p-6 relative overflow-hidden">
              <div class="relative z-10">
                <h3 class="text-indigo-400 text-sm font-bold mb-2">Secure Enclave Active</h3>
                <p class="text-[11px] text-indigo-300/60 leading-relaxed mb-4">
                  Multi-signature authorization for all transactions > $100k USD.
                </p>
                <div class="h-1 bg-white/5 rounded-full overflow-hidden">
                  <div class="w-2/3 h-full bg-indigo-500 rounded-full"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.dark_page>
    """
  end
end
