defmodule NexusWeb.Marketing.LandingLive do
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "NEXUS / Financial Architecture")
      |> assign(:revealed, false)

    if connected?(socket) do
      Process.send_after(self(), :reveal, 100)
    end

    {:ok, socket, layout: {NexusWeb.Layouts, :marketing}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative w-full min-h-screen bg-[#0B0E14] font-serif overflow-x-hidden">
      <div class={[
        "fixed inset-0 z-[100] bg-[#0B0E14] transition-transform duration-[1500ms] cubic-bezier(0.85, 0, 0.15, 1) pointer-events-none",
        @revealed && "-translate-y-full"
      ]}>
        <div class="h-full w-full flex items-center justify-center">
          <img
            src="/images/nexus_logo_full.png"
            alt="Nexus Loader"
            class="w-8 h-8 rounded-lg object-cover shadow-[0_0_20px_rgba(6,182,212,0.3)] animate-pulse"
          />
        </div>
      </div>

      <.editorial_grid />

      <div id="landing-main" phx-hook="ScrollReveal" class="relative z-10 font-sans tracking-tight">
        <header class="pt-32 pb-16 px-6 lg:px-12 border-b border-white/5 flex flex-col lg:flex-row lg:items-center justify-between gap-8 bg-[#0B0E14]">
          <div class="max-w-4xl">
            <h1 class="text-5xl md:text-7xl lg:text-[6rem] leading-[1.05] text-white font-extrabold mb-6">
              Institutional Financial Architecture.
            </h1>
            <p class="text-xl text-slate-400 max-w-2xl leading-relaxed">
              Nexus provides zero-trust identity, immutable event-sourced ledgers, and seamless SAP ERP integration for global enterprise.
            </p>
            <div class="flex items-center gap-4 mt-10">
              <.link
                navigate="/auth/gate?type=register"
                class="px-8 py-4 bg-white text-slate-900 font-bold rounded-lg hover:bg-slate-200 transition-colors shadow-lg active:scale-95"
              >
                Request Demo
              </.link>
              <a
                href="#platform"
                class="px-8 py-4 border border-white/10 text-white font-bold rounded-lg hover:bg-white/5 transition-colors active:scale-95"
              >
                Explore Platform
              </a>
            </div>
          </div>
          <div class="lg:text-right hidden xl:block">
            <div class="w-72 h-72 rounded-3xl bg-[#0B0E14]/40 border border-white/10 p-6 backdrop-blur-2xl relative overflow-hidden flex flex-col shadow-[0_0_50px_rgba(99,102,241,0.1)]">
              <%!-- Top Bar --%>
              <div class="flex items-center justify-between mb-6 relative z-10">
                <div class="flex items-center gap-2">
                  <div class="w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-[0_0_12px_#10b981] animate-pulse">
                  </div>
                  <span class="text-xs font-semibold text-emerald-400">Platform Sync</span>
                </div>
                <div class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold">
                  Global Edge
                </div>
              </div>

              <%!-- Main Metric --%>
              <div class="relative z-10 mb-auto mt-2 text-left">
                <div class="text-xs text-slate-400 font-medium mb-1">Volume Processed</div>
                <div class="text-4xl font-extrabold text-white tracking-tight flex items-baseline gap-1">
                  $1.2B <span class="text-sm font-semibold text-slate-500">/day</span>
                </div>
              </div>

              <%!-- Abstract Data Viz (Sine Wave) --%>
              <div class="absolute bottom-0 left-0 w-full h-32 opacity-40">
                <svg viewBox="0 0 100 40" preserveAspectRatio="none" class="w-full h-full">
                  <path
                    d="M0,40 Q10,10 20,25 T40,20 T60,30 T80,15 T100,25 L100,40 Z"
                    fill="url(#gradient-wave-1)"
                    class="animate-[pulse_4s_ease-in-out_infinite]"
                  />
                  <path
                    d="M0,40 Q15,15 30,25 T50,15 T70,30 T90,20 T100,35 L100,40 Z"
                    fill="url(#gradient-wave-2)"
                    class="animate-[pulse_3s_ease-in-out_infinite_reverse]"
                  />
                  <defs>
                    <linearGradient id="gradient-wave-1" x1="0%" y1="0%" x2="0%" y2="100%">
                      <stop offset="0%" stop-color="#6366f1" stop-opacity="0.8" />
                      <stop offset="100%" stop-color="#06b6d4" stop-opacity="0" />
                    </linearGradient>
                    <linearGradient id="gradient-wave-2" x1="0%" y1="0%" x2="0%" y2="100%">
                      <stop offset="0%" stop-color="#8b5cf6" stop-opacity="0.6" />
                      <stop offset="100%" stop-color="#3b82f6" stop-opacity="0" />
                    </linearGradient>
                  </defs>
                </svg>
              </div>

              <%!-- Bottom Detail overlay --%>
              <div class="relative z-10 pt-4 border-t border-white/10 flex justify-between items-end mt-4">
                <div class="text-left">
                  <div class="text-[10px] text-slate-500 font-semibold mb-0.5">LATENCY (P99)</div>
                  <div class="text-sm text-white font-semibold">1.04ms</div>
                </div>
                <div class="flex gap-1">
                  <div class="w-1 h-3 bg-white/20 rounded-full animate-pulse"></div>
                  <div
                    class="w-1 h-5 bg-indigo-500/50 rounded-full animate-pulse"
                    style="animation-delay: 0.2s"
                  >
                  </div>
                  <div
                    class="w-1 h-4 bg-cyan-500/50 rounded-full animate-pulse"
                    style="animation-delay: 0.4s"
                  >
                  </div>
                  <div
                    class="w-1 h-7 bg-indigo-400 rounded-full animate-pulse"
                    style="animation-delay: 0.6s"
                  >
                  </div>
                </div>
              </div>
            </div>
          </div>
        </header>

        <main class="border-b border-white/5 bg-[#0B0E14]">
          <section
            id="platform"
            class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5"
          >
            <div class="lg:col-span-7 p-8 lg:p-24 border-r border-white/5">
              <div class="reveal-text">
                <div class="w-12 h-12 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center mb-8 text-indigo-400">
                  <span class="hero-cube-transparent w-6 h-6"></span>
                </div>
                <h2 class="text-4xl md:text-5xl text-white font-bold mb-6">
                  Autonomous Multi-Tenant Partitioning.
                </h2>
                <div class="max-w-xl space-y-6">
                  <p class="text-slate-400 leading-relaxed text-lg">
                    Every organization on Nexus exists within a cryptographically unique partition. Unlike legacy multi-tenant databases, our architecture guarantees absolute data isolation at the compute layer, ensuring zero cross-tenant contamination.
                  </p>
                  <ul class="space-y-4 pt-4 text-slate-300">
                    <li class="flex items-center gap-3">
                      <span class="text-cyan-500">✓</span> Dedicated tenant event streams
                    </li>
                    <li class="flex items-center gap-3">
                      <span class="text-cyan-500">✓</span>
                      Hardware Security Module (HSM) key isolation
                    </li>
                    <li class="flex items-center gap-3">
                      <span class="text-cyan-500">✓</span> Independent read-model projectors
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            <div class="lg:col-span-5 p-12 lg:p-24 flex items-center justify-center bg-white/[0.01]">
              <.exhibit_container label="ISOLATION_TOPOLOGY">
                <.partition_cube />
              </.exhibit_container>
            </div>
          </section>

          <section
            id="integrations"
            class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5"
          >
            <div class="lg:col-span-5 border-r border-white/5 bg-white/[0.01] flex items-center justify-center p-12">
              <.exhibit_container label="EVENT_SOURCING_PULSE">
                <.ledger_stream />
              </.exhibit_container>
            </div>
            <div class="lg:col-span-7 p-8 lg:p-24 flex flex-col justify-center">
              <div class="reveal-text">
                <div class="w-12 h-12 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center mb-8 text-emerald-400">
                  <span class="hero-circle-stack w-6 h-6"></span>
                </div>
                <h2 class="text-4xl md:text-5xl text-white font-bold mb-6">
                  Immutable Ledger Archival.
                </h2>
                <p class="text-slate-400 leading-relaxed text-lg max-w-xl mb-8">
                  Nexus doesn't just store current state; it records history. Every transaction, mutation, and ledger update is an immutable event. Replay history perfectly for audit, compliance, or real-time SAP ERP replication.
                </p>

                <div class="grid grid-cols-2 gap-8 pt-8 border-t border-white/5">
                  <div>
                    <h4 class="text-white font-semibold mb-2">SOC 2 Compliant</h4>
                    <p class="text-slate-500 text-sm">
                      Automated cryptographic audit trails designed for enterprise compliance boards.
                    </p>
                  </div>
                  <div>
                    <h4 class="text-white font-semibold mb-2">SAP BAPI Ready</h4>
                    <p class="text-slate-500 text-sm">
                      Bi-directional event adapters to sync state directly with SAP S/4HANA instances.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section
            id="security"
            class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5"
          >
            <div class="lg:col-span-8 p-8 lg:p-24 border-r border-white/5">
              <div class="reveal-text">
                <div class="w-12 h-12 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center mb-8 text-rose-400">
                  <span class="hero-finger-print w-6 h-6"></span>
                </div>
                <h2 class="text-4xl md:text-5xl text-white font-bold mb-6">
                  Zero-Trust Hardware Identity.
                </h2>
                <p class="text-slate-400 leading-relaxed text-lg max-w-2xl mb-12">
                  Passwords belong in the past. Nexus relies entirely on FIDO2 WebAuthn protocols heavily integrated with device-level secure enclaves. Verify critical financial operations via Touch ID or Windows Hello, ensuring absolute cryptographic proof of presence.
                </p>

                <div class="flex gap-4">
                  <.link
                    navigate="/auth/gate?type=login"
                    class="px-8 py-4 bg-white/5 border border-white/10 text-white font-bold rounded-lg hover:bg-white/10 transition-colors active:scale-95"
                  >
                    Test Corporate Login Flow
                  </.link>
                </div>
              </div>
            </div>
            <div class="lg:col-span-4 p-12 bg-white/[0.01] flex flex-col justify-center items-center gap-6">
              <.exhibit_scanning_mask id="scan-03" label="WebAuthn Hardware Required">
                <p class="text-white text-center font-semibold mb-2">Biometric Enclave</p>
                <p class="text-slate-400 text-xs text-center">
                  Your private keys never leave the secure boundary of this device.
                </p>
                <:hidden_content>
                  <p class="text-emerald-400 font-mono text-xs text-center mt-4">
                    VERIFIED: ES256 SIGNATURE
                  </p>
                </:hidden_content>
              </.exhibit_scanning_mask>
            </div>
          </section>

          <section id="pricing" class="py-24 px-6 lg:px-12">
            <div class="max-w-3xl mx-auto text-center mb-16 reveal-text">
              <h2 class="text-3xl md:text-5xl text-white font-bold mb-4">
                Enterprise Architecture, Delivered.
              </h2>
              <p class="text-slate-400 text-lg">
                Predictable pricing designed to scale alongside your organization's transaction volume.
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
              <!-- Tier 1 -->
              <div class="bg-[#0B0E14] border border-white/10 rounded-2xl p-8 hover:border-white/20 transition-colors">
                <div class="text-slate-400 font-semibold mb-2">Developer</div>
                <div class="text-4xl font-bold text-white mb-6">
                  Free<span class="text-lg text-slate-500 font-normal">/forever</span>
                </div>
                <p class="text-sm text-slate-400 mb-8 pb-8 border-b border-white/5">
                  Perfect for exploring the event sourcing API and testing local integrations.
                </p>
                <ul class="space-y-4 text-sm text-slate-300 mb-8">
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Single Organization Tenant
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Up to 10,000 events/month
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> WebAuthn Identity Gate
                  </li>
                  <li class="flex items-center gap-3 text-slate-600">
                    <span class="opacity-0">✓</span> SAP Adapter
                  </li>
                </ul>
                <button class="w-full py-3 rounded-lg border border-white/10 text-white font-semibold hover:bg-white/5 transition-all">
                  Start Building
                </button>
              </div>
              
    <!-- Tier 2 -->
              <div class="bg-gradient-to-b from-indigo-500/10 to-[#0B0E14] border border-indigo-500/30 rounded-2xl p-8 transform md:-translate-y-4 shadow-2xl relative">
                <div class="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-indigo-500 text-white text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full">
                  Most Popular
                </div>
                <div class="text-indigo-400 font-semibold mb-2">Professional</div>
                <div class="text-4xl font-bold text-white mb-6">
                  $499<span class="text-lg text-slate-500 font-normal">/mo</span>
                </div>
                <p class="text-sm text-slate-400 mb-8 pb-8 border-b border-indigo-500/10">
                  Full financial capabilities for mid-market treasury and asset management.
                </p>
                <ul class="space-y-4 text-sm text-slate-300 mb-8">
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> 5 Organization Tenants
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> 1M events/month
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Priority Read-Models
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> SOC 2 Audit Exports
                  </li>
                </ul>
                <button class="w-full py-3 rounded-lg bg-indigo-600 text-white font-semibold hover:bg-indigo-700 transition-all shadow-lg shadow-indigo-500/20">
                  Upgrade to Pro
                </button>
              </div>
              
    <!-- Tier 3 -->
              <div class="bg-[#0B0E14] border border-white/10 rounded-2xl p-8 hover:border-white/20 transition-colors">
                <div class="text-slate-400 font-semibold mb-2">Enterprise</div>
                <div class="text-4xl font-bold text-white mb-6">Custom</div>
                <p class="text-sm text-slate-400 mb-8 pb-8 border-b border-white/5">
                  Dedicated infrastructure with SAP adapters for global conglomerates.
                </p>
                <ul class="space-y-4 text-sm text-slate-300 mb-8">
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Unlimited Tenants
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Dedicated HSM Enclaves
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> SAP S/4HANA & NetWeaver Adapters
                  </li>
                  <li class="flex items-center gap-3">
                    <span class="text-indigo-400">✓</span> Custom Ledger Projections
                  </li>
                </ul>
                <button class="w-full py-3 rounded-lg border border-white/10 text-white font-semibold hover:bg-white/5 transition-all">
                  Contact Sales
                </button>
              </div>
            </div>
          </section>
        </main>

        <footer class="py-12 px-6 lg:px-12 flex flex-col md:flex-row justify-between items-center gap-6 border-t border-white/5">
          <div class="flex items-center gap-3">
            <span class="text-white font-bold">NEXUS</span>
            <span class="text-slate-500 text-sm">
              © {DateTime.utc_now().year} All rights reserved.
            </span>
          </div>
          <div class="flex gap-6 text-sm text-slate-400">
            <a href="#" class="hover:text-white transition-colors">Privacy Policy</a>
            <a href="#" class="hover:text-white transition-colors">Terms of Service</a>
            <a href="#" class="hover:text-white transition-colors">Security</a>
            <a href="#" class="hover:text-white transition-colors">System Status</a>
          </div>
        </footer>
      </div>

      <.precision_cursor />
    </div>
    """
  end

  @impl true
  def handle_info(:reveal, socket) do
    {:noreply, assign(socket, :revealed, true)}
  end
end
