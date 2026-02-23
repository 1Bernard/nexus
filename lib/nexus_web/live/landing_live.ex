defmodule NexusWeb.LandingLive do
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
          <div class="flex flex-col items-center">
            <div class="text-[10px] font-mono tracking-[0.5em] text-slate-500 uppercase mb-4">
              ACCESS_LEVEL: PLATFORM
            </div>
            <div class="w-px h-12 bg-white/20 animate-pulse"></div>
          </div>
        </div>
      </div>

      <.editorial_grid />

      <div id="landing-main" phx-hook="ScrollReveal" class="relative z-10 font-serif">
        <header class="pt-24 pb-12 px-6 lg:px-12 border-b border-white/5 flex flex-col lg:flex-row lg:items-end justify-between gap-8 bg-[#0B0E14]">
          <div class="max-w-4xl">
            <div class="text-[9px] font-mono tracking-[0.4em] text-cyan-500 uppercase mb-4">
              ISSUE 01: THE LIVING LABORATORY
            </div>
            <h1 class="text-7xl md:text-[10rem] lg:text-[14rem] leading-[0.85] text-white tracking-tighter uppercase font-black">
              NEXUS
            </h1>
          </div>
          <div class="lg:text-right">
            <div class="text-[9px] font-mono tracking-[0.4em] text-cyan-500/30 uppercase mb-2">
              SYSTEM_CLOCK // {DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")} UTC
            </div>
            <div class="text-xs font-mono text-slate-400 uppercase">PROTOCOL_V: 2.1.0-PRE</div>
          </div>
        </header>

        <main class="border-b border-white/5 bg-[#0B0E14]">
          <section class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5">
            <div class="lg:col-span-7 p-6 lg:p-24 border-r border-white/5">
              <div class="reveal-text">
                <p class="text-[10px] font-mono tracking-[0.4em] text-cyan-500 uppercase mb-8 italic">
                  01 // AUTOMATED_ISOLATION
                </p>
                <h2 class="text-5xl md:text-7xl text-white leading-[0.9] mb-12 uppercase font-black tracking-tighter">
                  Autonomous <br /> Partitioning.
                </h2>
                <div class="max-w-xl space-y-6">
                  <p class="text-slate-400 leading-relaxed font-sans text-lg">
                    Every organization on Nexus exists within a cryptographically unique partition. Unlike legacy multi-tenant systems, our architecture ensures zero bleed-through at the compute layer.
                  </p>
                  <div class="pt-8 border-t border-white/5 flex gap-12">
                    <div>
                      <div class="text-[8px] font-mono text-slate-500 uppercase mb-2">
                        ENCLAVE_TYPE
                      </div>
                      <div class="text-xs font-mono text-cyan-500 uppercase">HSM_ISOLATED</div>
                    </div>
                    <div>
                      <div class="text-[8px] font-mono text-slate-500 uppercase mb-2">LATENCY</div>
                      <div class="text-xs font-mono text-cyan-500 uppercase">&lt; 1.2ms</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="lg:col-span-5 p-12 lg:p-24 flex items-center justify-center bg-white/[0.01]">
              <.exhibit_container label="INTERACTIVE_CORE_VIEWER">
                <.partition_cube />
                <:footer>
                  <div class="flex items-center justify-between text-[8px] font-mono text-slate-500 uppercase">
                    <span>Rotation: MOUSE_X / MOUSE_Y</span>
                    <span class="text-cyan-500">READY</span>
                  </div>
                </:footer>
              </.exhibit_container>
            </div>
          </section>

          <section class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5">
            <div class="lg:col-span-5 border-r border-white/5 bg-white/[0.01]">
              <.exhibit_container label="EVENT_STORE_PULSE">
                <.ledger_stream />
                <:footer>
                  <div class="text-[8px] font-mono text-slate-500 uppercase">
                    REAL_TIME_EVENT_INGESTION_ACTIVE
                  </div>
                </:footer>
              </.exhibit_container>
            </div>
            <div class="lg:col-span-7 p-6 lg:p-24 flex flex-col justify-center">
              <div class="reveal-text">
                <p class="text-[10px] font-mono tracking-[0.4em] text-violet-400 uppercase mb-8 italic">
                  02 // IMMUTABILITY_LAYER
                </p>
                <h2 class="text-5xl md:text-7xl text-white leading-[0.9] mb-12 uppercase font-black tracking-tighter">
                  Infinite <br /> Archival.
                </h2>
                <p class="text-slate-400 leading-relaxed font-sans text-lg max-w-xl">
                  Nexus doesn't just store state; it records history. Every transaction is an immutable event, providing a perfect audit trail from genesis to the current block. High-performance event sourcing at its peak.
                </p>

                <div class="mt-12 flex gap-4">
                  <.link
                    navigate="/auth/gate"
                    class="interactive px-8 py-4 bg-white text-black font-mono text-[9px] uppercase tracking-[0.3em] hover:bg-cyan-500 transition-colors"
                  >
                    Initialize Breach
                  </.link>
                  <button class="interactive px-8 py-4 border border-white/10 text-white font-mono text-[9px] uppercase tracking-[0.3em] hover:border-white transition-colors">
                    System Status
                  </button>
                </div>
              </div>
            </div>
          </section>

          <section class="grid grid-cols-1 lg:grid-cols-12 gap-0 border-b border-white/5">
            <div class="lg:col-span-8 p-6 lg:p-24 border-r border-white/5">
              <div class="reveal-text">
                <p class="text-[10px] font-mono tracking-[0.4em] text-cyan-500 uppercase mb-8 italic">
                  03 // IDENTITY_GATE
                </p>
                <h2 class="text-5xl md:text-7xl text-white leading-[0.9] mb-12 uppercase font-black tracking-tighter">
                  Encrypted <br /> Signatures.
                </h2>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                  <.exhibit_scanning_mask id="scan-01" label="USER_ID: NX-8842">
                    <p class="text-slate-200 font-serif text-2xl italic">"The user is the key."</p>
                    <:hidden_content>
                      <p>BIO_HASH: 0x8F2...91A</p>
                      <p>ENCLAVE_ID: SEC-04B</p>
                      <p>STATUS: VERIFIED</p>
                    </:hidden_content>
                  </.exhibit_scanning_mask>

                  <.exhibit_scanning_mask id="scan-02" label="USER_ID: NX-1109">
                    <p class="text-slate-200 font-serif text-2xl italic">"Biometric isolation."</p>
                    <:hidden_content>
                      <p>BIO_HASH: 0xDF1...D22</p>
                      <p>ENCLAVE_ID: SEC-09X</p>
                      <p>STATUS: ACTIVE</p>
                    </:hidden_content>
                  </.exhibit_scanning_mask>
                </div>
              </div>
            </div>
            <div class="lg:col-span-4 p-12 bg-white/[0.01] flex flex-col items-center justify-center text-center">
              <div class="w-px h-24 bg-gradient-to-b from-transparent via-cyan-500 to-transparent mb-12">
              </div>
              <p class="text-slate-400 font-mono text-[9px] uppercase tracking-widest mb-8">
                Ready to Breach?
              </p>
              <.link
                navigate="/auth/gate"
                class="interactive group relative px-12 py-6 bg-white text-black font-mono text-[10px] uppercase tracking-[0.5em] hover:bg-cyan-500 transition-all active:scale-95"
              >
                Authorize Access
              </.link>
            </div>
          </section>
        </main>

        <footer class="py-24 px-6 lg:px-12 flex flex-col md:flex-row justify-between items-center gap-12 opacity-50 grayscale hover:grayscale-0 transition-all duration-1000">
          <div class="text-[10px] font-mono tracking-[0.3em] text-slate-500 uppercase">
            © {DateTime.utc_now().year} NEXUS RESEARCH LABORATORY / BEYOND THE VOID
          </div>
          <div class="flex gap-8">
            <a
              href="#"
              class="text-[10px] font-mono tracking-widest uppercase hover:text-cyan-500 transition-colors"
            >
              Twitter
            </a>
            <a
              href="#"
              class="text-[10px] font-mono tracking-widest uppercase hover:text-cyan-500 transition-colors"
            >
              GitHub
            </a>
            <a
              href="#"
              class="text-[10px] font-mono tracking-widest uppercase hover:text-cyan-500 transition-colors"
            >
              HackerNews
            </a>
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
