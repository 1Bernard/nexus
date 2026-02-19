defmodule NexusWeb.Identity.BiometricComponents do
  use Phoenix.Component

  attr :activeIndex, :integer, required: true

  def step_indicators(assigns) do
    ~H"""
    <div class="flex gap-1.5" id="stepDots">
      <div
        :for={idx <- 0..3}
        class={[
          "step-dot h-1.5 rounded-full transition-all",
          if(idx == @activeIndex,
            do: "w-8 bg-indigo-500 shadow-[0_0_12px_rgba(99,102,241,0.7)]",
            else: "w-4 bg-white/10"
          )
        ]}
      >
      </div>
    </div>
    """
  end

  def security_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/5 rounded-full border border-emerald-500/15">
      <span class="relative flex h-2 w-2">
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-400"></span>
      </span>
      <span class="text-[9px] font-mono font-semibold uppercase tracking-widest text-emerald-400">
        AES-256 | HSM
      </span>
    </div>
    """
  end

  # idle, scanning, success, error
  attr :status, :string, default: "idle"
  attr :progress, :integer, default: 0

  def sensor_ring(assigns) do
    ~H"""
    <div class="relative my-6 flex items-center justify-center">
      <div
        id="sensorOuterRing"
        class={[
          "absolute w-64 h-64 rounded-full border border-white/5 transition-all duration-300",
          @status == "scanning" && "border-indigo-500/40 scale-110"
        ]}
      >
      </div>
      <div
        id="sensorPing"
        class={[
          "absolute w-64 h-64 rounded-full bg-indigo-500/10 animate-ping",
          @status != "scanning" && "hidden"
        ]}
      >
      </div>

      <button
        id="biometricSensor"
        phx-hook="WebAuthnHook"
        class="relative w-48 h-48 rounded-full flex items-center justify-center transition-all duration-200 touch-none bg-white/5 ring-1 ring-white/10 touch-feedback"
      >
        <div class="relative w-56 h-56 flex items-center justify-center pointer-events-none">
          <!-- Background Ring -->
          <svg
            class="absolute inset-0 w-full h-full -rotate-90 overflow-visible"
            viewBox="0 0 100 100"
          >
            <circle
              cx="50"
              cy="50"
              r="46"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              class="text-white/5"
            />
            <!-- Progress Ring (Managed by JS via --scan-p) -->
            <circle
              id="progressRing"
              cx="50"
              cy="50"
              r="46"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-dasharray="290"
              style="stroke-dashoffset: calc(290 - (290 * var(--scan-p, 0)) / 100);"
              class={[
                "text-indigo-500 transition-all duration-75 ease-out",
                @status == "success" && "text-emerald-500 shadow-[0_0_15px_rgba(16,185,129,0.5)]"
              ]}
            />
          </svg>
        </div>

        <div
          id="sensorIconWrapper"
          class={[
            "absolute inset-0 flex items-center justify-center transition-all",
            cond do
              @status == "success" -> "text-emerald-400"
              @status == "scanning" -> "text-indigo-400"
              true -> "text-slate-300"
            end
          ]}
        >
          <svg
            id="fingerprintIcon"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class={["w-16 h-16", @status == "success" && "hidden"]}
          >
            <%!-- Lucide fingerprint icon --%>
            <path d="M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4" />
            <path d="M14 13.12c0 2.38 0 6.38-1 8.88" />
            <path d="M17.29 21.02c.12-.6.43-2.3.5-3.02" />
            <path d="M2 12a10 10 0 0 1 18-6" />
            <path d="M2 16h.01" />
            <path d="M21.8 16c.2-2 .131-5.354 0-6" />
            <path d="M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2" />
            <path d="M8.65 22c.21-.66.45-1.32.57-2" />
            <path d="M9 6.8a6 6 0 0 1 9 5.2v2" />
          </svg>
          <svg
            id="shieldCheckIcon"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class={["w-16 h-16", @status != "success" && "hidden"]}
          >
            <%!-- Lucide shield-check icon --%>
            <path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" />
            <path d="m9 12 2 2 4-4" />
          </svg>
        </div>
        <!-- scanning beam -->
        <div
          id="scanBeam"
          class={[
            "absolute left-4 right-4 h-0.5 bg-indigo-400/80 shadow-[0_0_12px_#818cf8] pointer-events-none transition-opacity",
            if(@status == "scanning", do: "opacity-100 animate-scan-beam", else: "opacity-0")
          ]}
        >
        </div>
      </button>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  def feature_item(assigns) do
    ~H"""
    <div class="flex gap-4">
      <div class="w-9 h-9 bg-white/5 rounded-xl flex items-center justify-center text-slate-400">
        <span class={["w-4 h-4", @icon]}></span>
      </div>
      <div>
        <h3 class="font-semibold text-sm">{@title}</h3>
        <p class="text-[10px] text-slate-500 mt-0.5">{@subtitle}</p>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :status, :atom, required: true

  def status_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 rounded-xl bg-white/5 border border-white/5">
      <span class="text-xs text-slate-300">{@label}</span>
      <span class={[
        "text-[10px] font-bold uppercase tracking-widest",
        @status in [:passed, :clear, :low_risk] && "text-emerald-400",
        @status == :scanning && "text-amber-400 animate-pulse"
      ]}>
        <%= case @status do %>
          <% :scanning -> %>
            scanning ⋯
          <% :passed -> %>
            ✓ passed
          <% :clear -> %>
            ✓ clear
          <% :low_risk -> %>
            ✓ low risk
          <% _ -> %>
            waiting
        <% end %>
      </span>
    </div>
    """
  end

  # -- Step Content Templates --
  # These render the body of each step in the biometric flow.
  # The LiveView dispatches to these via pattern matching on the :step assign.

  attr :step, :atom, required: true
  attr :status, :string, default: "idle"
  attr :progress, :integer, default: 0
  attr :v_id, :string, default: nil
  attr :error, :string, default: nil
  attr :challenge, :string, default: nil
  attr :consent_checked, :boolean, default: false
  attr :screening, :map, default: %{}

  def step_content(%{step: :welcome} = assigns) do
    ~H"""
    <div class="fade-up">
      <div class="w-14 h-14 bg-indigo-500/10 rounded-2xl flex items-center justify-center mb-6 ring-1 ring-indigo-500/30">
        <span class="hero-shield-check w-7 h-7 text-indigo-400"></span>
      </div>
      <h1 class="text-3xl font-bold mb-3 tracking-tight">Nexus Identity Gate</h1>
      <p class="text-slate-400 text-sm leading-relaxed mb-7">
        Secure your Nexus terminal with hardware-bound biometrics. Your fingerprint never leaves the device.
      </p>

      <div class="space-y-4 mb-8">
        <.feature_item
          icon="hero-finger-print"
          title="Device-bound key"
          subtitle="Your biometric creates a cryptographic key stored only on this device"
        />
        <.feature_item
          icon="hero-cpu-chip"
          title="Nexus Secure Enclave"
          subtitle="Trusted execution environment · zero raw biometric storage"
        />
        <.feature_item
          icon="hero-bolt"
          title="Instant activation"
          subtitle="One step to unlock full Nexus access"
        />
      </div>

      <button
        phx-click="next_step"
        phx-value-step="consent"
        class="w-full py-4 bg-indigo-600 active:bg-indigo-700 text-white font-semibold rounded-xl transition-all shadow-xl shadow-indigo-600/20 flex items-center justify-center gap-2 touch-feedback"
      >
        <span>Begin identity verification</span>
        <span class="hero-arrow-right w-4 h-4"></span>
      </button>
      <p class="text-[9px] text-center text-slate-600 mt-4">
        🔒 Nexus encrypted session · end-to-end
      </p>
    </div>
    """
  end

  def step_content(%{step: :consent} = assigns) do
    ~H"""
    <div class="fade-up">
      <h2 class="text-2xl font-bold mb-3">Nexus data processing notice</h2>
      <div class="bg-white/5 border border-white/10 rounded-xl p-4 mb-6 text-xs text-slate-300 max-h-40 overflow-y-auto scroll-soft leading-relaxed">
        <p class="mb-2">
          Nexus uses <strong>device-bound credentials</strong> to verify your identity.
          Your biometric data is processed entirely on your device — Nexus never sees or stores raw biometric data.
        </p>
        <ul class="list-disc ml-4 space-y-1.5 text-slate-400 text-[11px]">
          <li>A cryptographic key pair is generated on your device's secure enclave.</li>
          <li>Only the public key is shared with Nexus — your fingerprint stays on-device.</li>
          <li>Credentials can be revoked at any time from your Nexus dashboard.</li>
          <li>Compliant with GDPR Article 9(2)(a) and CCPA biometric data provisions.</li>
        </ul>
      </div>

      <div class="flex items-start gap-3 mb-8">
        <input
          type="checkbox"
          id="consentCheckbox"
          phx-click="toggle_consent"
          checked={@consent_checked}
          class="mt-1 w-5 h-5 rounded border-white/20 bg-white/5 text-indigo-600 focus:ring-indigo-500"
        />
        <label for="consentCheckbox" class="text-xs text-slate-300 leading-relaxed">
          I confirm that I have read and accept the
          <span class="text-indigo-400 underline">data processing notice</span>
          and consent to biometric verification.
        </label>
      </div>

      <button
        id="consentConfirmBtn"
        phx-click="next_step"
        phx-value-step="biometric"
        disabled={not @consent_checked}
        class={[
          "w-full py-4 bg-white text-slate-900 font-bold rounded-xl transition-all active:scale-95 touch-feedback",
          not @consent_checked && "opacity-50 cursor-not-allowed"
        ]}
      >
        Confirm & continue
      </button>
      <button
        phx-click="next_step"
        phx-value-step="welcome"
        class="w-full mt-3 py-3 border border-white/10 text-slate-400 text-sm rounded-xl active:bg-white/5"
      >
        Back
      </button>
    </div>
    """
  end

  def step_content(%{step: :biometric} = assigns) do
    ~H"""
    <div class="fade-up text-center flex flex-col items-center" data-challenge={@challenge}>
      <h2 class="text-2xl font-bold">Biometric verification</h2>
      <p class="text-xs text-slate-400 mt-1 mb-4">Press and hold to verify your identity</p>

      <.sensor_ring status={@status} progress={@progress} />

      <div id="biometricHint" phx-update="ignore" class="h-6 text-[10px] font-mono text-slate-500">
        <span>⬇️ press &amp; hold to verify ⬇️</span>
      </div>

      <button
        phx-click="next_step"
        phx-value-step="consent"
        class="w-full mt-3 py-3 border border-white/10 text-slate-400 text-sm rounded-xl"
      >
        ← cancel
      </button>

      <div class="mt-8 w-full space-y-3">
        <div class="flex items-center justify-center gap-5 text-[9px] text-slate-500">
          <span class="flex items-center gap-1.5">
            <span class="hero-device-phone-mobile w-3.5 h-3.5 text-indigo-400/60"></span>
            On-device only
          </span>
          <span class="w-px h-3 bg-white/10"></span>
          <span class="flex items-center gap-1.5">
            <span class="hero-eye-slash w-3.5 h-3.5 text-indigo-400/60"></span> Zero-knowledge
          </span>
          <span class="w-px h-3 bg-white/10"></span>
          <span class="flex items-center gap-1.5">
            <span class="hero-shield-check w-3.5 h-3.5 text-indigo-400/60"></span> FIDO2 / WebAuthn
          </span>
        </div>
        <p class="text-[8px] text-slate-600 text-center leading-relaxed">
          Your biometric never leaves this device. Only a cryptographic
          signature is transmitted — Nexus cannot access or reconstruct your fingerprint.
        </p>
      </div>
    </div>
    """
  end

  def step_content(%{step: :verifying} = assigns) do
    ~H"""
    <div class="fade-up flex flex-col items-center pt-4">
      <div class="relative w-20 h-20 mb-5">
        <div class="absolute inset-0 border-4 border-indigo-500/10 rounded-full"></div>
        <div class="absolute inset-0 border-4 border-t-indigo-500 rounded-full animate-spin"></div>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="hero-viewfinder-circle w-7 h-7 text-indigo-400"></span>
        </div>
      </div>
      <h3 class="text-xl font-bold">Verification in progress</h3>
      <p class="text-xs text-slate-400 mb-6">Verifying your identity</p>

      <div class="w-full space-y-3">
        <.status_item label="Identity verification" status={@screening.fuzzy} />
        <.status_item label="Compliance clearance" status={@screening.ofac} />
        <.status_item label="Risk assessment" status={@screening.pep} />
      </div>

      <button
        :if={@screening.pep == :low_risk}
        phx-click="next_step"
        phx-value-step="success"
        class="mt-8 text-indigo-400 text-xs animate-pulse font-mono tracking-widest uppercase"
      >
        [ CONTINUE ]
      </button>

      <p class="text-[9px] text-slate-600 mt-6">ref: {@v_id}</p>
    </div>
    """
  end

  def step_content(%{step: :success} = assigns) do
    ~H"""
    <div class="fade-up flex flex-col items-center pt-6">
      <div class="w-20 h-20 bg-emerald-500/20 rounded-full flex items-center justify-center mb-5 ring-8 ring-emerald-500/10 text-emerald-400">
        <span class="hero-check-badge w-10 h-10"></span>
      </div>
      <h2 class="text-2xl font-bold">Nexus access granted</h2>
      <p class="text-sm text-slate-400 mt-1 mb-8 text-center">
        Identity verified.<br />Full access activated.
      </p>

      <div class="w-full bg-white/5 border border-white/10 p-5 rounded-2xl mb-8 text-left">
        <div class="flex justify-between mb-3">
          <span class="text-[9px] text-slate-500">verification ID</span>
          <span class="text-[10px] font-mono text-indigo-300">{@v_id}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-[9px] text-slate-500">risk score</span>
          <span class="text-[10px] font-bold text-emerald-400">LOW / 1.2</span>
        </div>
      </div>
      <button
        phx-click="go_to_dashboard"
        class="w-full py-4 bg-indigo-600 text-white font-bold rounded-xl shadow-xl active:scale-95"
      >
        Enter Nexus dashboard
      </button>
    </div>
    """
  end

  def step_content(%{step: :error} = assigns) do
    ~H"""
    <div class="fade-up flex flex-col items-center pt-6">
      <div class="w-20 h-20 bg-rose-500/20 rounded-full flex items-center justify-center mb-5 ring-8 ring-rose-500/10 text-rose-400">
        <span class="hero-exclamation-triangle w-10 h-10"></span>
      </div>
      <h2 class="text-2xl font-bold">Verification failed</h2>
      <p class="text-sm text-slate-400 mt-1 mb-8 text-center">{@error}</p>

      <button
        phx-click="next_step"
        phx-value-step="biometric"
        class="w-full py-4 bg-white text-slate-900 font-bold rounded-xl shadow-xl active:scale-95"
      >
        Retry verification
      </button>
    </div>
    """
  end
end
