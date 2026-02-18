// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Established Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
// import {hooks as colocatedHooks} from "phoenix-colocated/nexus"
import topbar from "../vendor/topbar"

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

let Hooks = { }; // colocatedHooks removed as it was unresolved

Hooks.WebAuthnHook = {
  mounted() {
    this.scanInterval = null;
    this.progress = 0;
    this.scanning = false;

    // Standardize pointer events to avoid context menu / scroll interference
    this.el.addEventListener("pointerdown", (e) => {
      // Prevent context menus on mobile/machold
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
    
    // Attempt to lock the pointer to this element
    try {
      this.el.setPointerCapture(e.pointerId);
    } catch(err) {
      console.warn("Pointer capture failed:", err);
    }

    this.scanning = true;
    this.progress = 0;
    this.el.style.setProperty("--scan-p", "0");
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
    
    if (e?.pointerId) {
      try { this.el.releasePointerCapture(e.pointerId); } catch(err) {}
    }
    
    clearInterval(this.scanInterval);
    this.scanning = false;
    
    // Reset local visual state immediately
    this.el.style.setProperty("--scan-p", "0");

    if (this.progress < 100) {
      this.pushEvent("biometric_reset", {retry_count: 1});
    }
  },

  destroyed() {
    clearInterval(this.scanInterval);
  },

  async finishScan() {
    clearInterval(this.scanInterval);
    this.scanning = false;

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
      this.pushEvent("biometric_reset", {error: err.message});
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

