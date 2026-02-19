/**
 * WebAuthn Biometric Hook
 *
 * Handles the client-side biometric verification flow:
 *  - Pointer-based press-and-hold sensor interaction
 *  - Real-time visual feedback (progress ring, scan beam, color transitions)
 *  - WebAuthn credential creation via navigator.credentials.create()
 *  - Retry logic with cooldown between attempts
 *
 * Communicates with BiometricLive via pushEvent/handleEvent over the LiveSocket.
 */

// ── Base64URL ↔ ArrayBuffer helpers ──────────────────────────────────

const WebAuthnUtils = {
  arrayBufferToBase64URL: (buffer) => {
    let binary = "";
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  },
  base64URLToBuffer: (base64url) => {
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
    const padLen = (4 - (base64.length % 4)) % 4;
    const padded = base64.padEnd(base64.length + padLen, "=");
    const binary = window.atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }
};

// ── DOM helpers ──────────────────────────────────────────────────────

function getElements() {
  return {
    outerRing:    document.getElementById("sensorOuterRing"),
    ping:         document.getElementById("sensorPing"),
    beam:         document.getElementById("scanBeam"),
    iconWrapper:  document.getElementById("sensorIconWrapper"),
    hint:         document.getElementById("biometricHint"),
    progressRing: document.getElementById("progressRing"),
    fingerprint:  document.getElementById("fingerprintIcon"),
    shieldCheck:  document.getElementById("shieldCheckIcon"),
  };
}

// ── Hook ─────────────────────────────────────────────────────────────

const WebAuthnHook = {
  mounted() {
    this.scanInterval = null;
    this.progress = 0;
    this.scanning = false;
    this.retryCount = 0;
    this.maxRetries = 2;
    this.cooldownActive = false;
    this.cooldownTimer = null;

    // Standardize pointer events to avoid context menu / scroll interference
    this.el.addEventListener("pointerdown", (e) => {
      // Prevent context menus on mobile/mac hold
      if (e.pointerType === "touch" || e.button === 0) {
        this.startScan(e);
      }
    });
    this.el.addEventListener("pointerup", (e) => this.stopScan(e));
    this.el.addEventListener("pointerleave", (e) => this.stopScan(e));
    this.el.addEventListener("contextmenu", (e) => e.preventDefault());
  },

  startScan(e) {
    if (this.scanning) return;
    if (this.cooldownActive) return; // Wait for retry hint to be readable
    if (this.retryCount >= this.maxRetries) {
      const { hint } = getElements();
      if (hint) hint.innerHTML = '<span class="text-rose-400">❌ too many attempts — reload to retry</span>';
      return;
    }

    // Attempt to lock the pointer to this element
    try {
      this.el.setPointerCapture(e.pointerId);
    } catch(err) {
      console.warn("Pointer capture failed:", err);
    }

    this.scanning = true;
    this.progress = 0;
    this.el.style.setProperty("--scan-p", "0");

    // === INSTANT CLIENT-SIDE VISUAL FEEDBACK ===
    const { outerRing, ping, beam, iconWrapper, hint } = getElements();

    if (outerRing) {
      outerRing.classList.remove("border-white/5");
      outerRing.classList.add("border-indigo-500/40", "scale-110");
    }
    if (ping) ping.classList.remove("hidden");
    if (beam) {
      beam.classList.remove("opacity-0");
      beam.classList.add("opacity-100", "animate-scan-beam");
    }
    if (iconWrapper) {
      iconWrapper.classList.remove("text-slate-300");
      iconWrapper.classList.add("text-indigo-400");
    }
    if (hint) hint.innerHTML = '<span class="text-indigo-400">🔗 scanning ⋯ hold still</span>';

    // Server notification (fire-and-forget for state tracking)
    this.pushEvent("biometric_start", {});

    this.scanInterval = setInterval(() => {
      this.progress += 2;
      if (this.progress >= 100) {
        this.progress = 100;
        this.el.style.setProperty("--scan-p", "100");
        this.finishScan();
      } else {
        // High-fidelity local update vs server roundtrip
        this.el.style.setProperty("--scan-p", this.progress.toString());
      }
    }, 20); // Faster, smoother local check
  },

  stopScan(e) {
    if (!this.scanning) return;
    if (this.progress >= 100) return; // Already finishing

    if (e?.pointerId) {
      try { this.el.releasePointerCapture(e.pointerId); } catch(err) {}
    }

    clearInterval(this.scanInterval);
    this.scanning = false;
    this.retryCount++;

    // === INSTANT VISUAL RESET ===
    this.resetVisuals();

    // Retry feedback with color-coded hints
    const { hint } = getElements();
    if (hint) {
      if (this.retryCount < this.maxRetries) {
        hint.innerHTML = `<span class="text-amber-400">⚠️ incomplete scan (${this.retryCount}/${this.maxRetries}) — press &amp; hold again</span>`;
      } else {
        hint.innerHTML = '<span class="text-rose-400">❌ too many attempts — reload to retry</span>';
      }
    }

    // Reset progress bar
    this.el.style.setProperty("--scan-p", "0");

    // === COOLDOWN: keep hint visible for 2s, block new scans ===
    this.cooldownActive = true;
    clearTimeout(this.cooldownTimer);
    this.cooldownTimer = setTimeout(() => {
      this.cooldownActive = false;
    }, 2000);

    this.pushEvent("biometric_reset", {retry_count: this.retryCount});
  },

  resetVisuals() {
    const { outerRing, ping, beam, iconWrapper, progressRing, fingerprint, shieldCheck } = getElements();

    if (outerRing) {
      outerRing.classList.remove("border-indigo-500/40", "scale-110");
      outerRing.classList.add("border-white/5");
    }
    if (ping) ping.classList.add("hidden");
    if (beam) {
      beam.classList.remove("opacity-100", "animate-scan-beam");
      beam.classList.add("opacity-0");
    }
    if (iconWrapper) {
      iconWrapper.classList.remove("text-indigo-400", "text-emerald-400");
      iconWrapper.classList.add("text-slate-300");
    }

    // Reset progress ring color
    if (progressRing) {
      progressRing.classList.remove("text-emerald-500");
      progressRing.classList.add("text-indigo-500");
    }

    // Reset icon visibility
    if (fingerprint) fingerprint.classList.remove("hidden");
    if (shieldCheck) shieldCheck.classList.add("hidden");
  },

  destroyed() {
    clearInterval(this.scanInterval);
    clearTimeout(this.cooldownTimer);
  },

  async finishScan() {
    clearInterval(this.scanInterval);
    this.scanning = false;

    // === INSTANT SUCCESS VISUALS (before WebAuthn prompt) ===
    const { iconWrapper, fingerprint, shieldCheck, beam, hint, progressRing } = getElements();

    // Swap icons
    if (fingerprint) fingerprint.classList.add("hidden");
    if (shieldCheck) shieldCheck.classList.remove("hidden");

    // Color transitions
    if (iconWrapper) {
      iconWrapper.classList.remove("text-slate-300", "text-indigo-400");
      iconWrapper.classList.add("text-emerald-400");
    }
    if (progressRing) {
      progressRing.classList.remove("text-indigo-500");
      progressRing.classList.add("text-emerald-500");
    }

    // Hide beam
    if (beam) {
      beam.classList.remove("opacity-100", "animate-scan-beam");
      beam.classList.add("opacity-0");
    }

    // Success hint
    if (hint) hint.innerHTML = '<span class="text-emerald-400">✓ biometric verified</span>';

    const challengeBase64URL = this.el.closest("[data-challenge]")?.dataset.challenge;

    if (!challengeBase64URL) {
      console.error("No challenge found in DOM");
      return;
    }

    try {
      const options = {
        publicKey: {
          challenge: WebAuthnUtils.base64URLToBuffer(challengeBase64URL),
          rp: { name: "Nexus Industrial", id: window.location.hostname },
          user: {
            id: WebAuthnUtils.base64URLToBuffer(WebAuthnUtils.arrayBufferToBase64URL(crypto.getRandomValues(new Uint8Array(16)))),
            name: "trader_session_" + Math.random().toString(36).substring(7),
            displayName: "Nexus Trader"
          },
          pubKeyCredParams: [
            { alg: -7, type: "public-key" }, // ES256
            { alg: -257, type: "public-key" } // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: "platform",
            userVerification: "required",
            residentKey: "preferred"
          },
          timeout: 60000,
          attestation: "none" // 'direct' often triggers extra warnings/prompts
        }
      };

      const credential = await navigator.credentials.create(options);

      this.pushEvent("biometric_complete", {
        attestation_object: WebAuthnUtils.arrayBufferToBase64URL(credential.response.attestationObject),
        client_data_json: WebAuthnUtils.arrayBufferToBase64URL(credential.response.clientDataJSON)
      });

    } catch (err) {
      console.error("Biometric failed:", err);
      this.resetVisuals();
      this.pushEvent("biometric_reset", {error: err.message});
    }
  }
};

export default WebAuthnHook;
