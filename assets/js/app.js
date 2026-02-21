// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Established Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
const Hooks = {}

Hooks.NavInteractions = {
  mounted() {
    this.railToggle = this.el.querySelector('#rail-toggle')
    this.appShell = this.el
    
    // Notifications Dropdown
    this.notifBtn = this.el.querySelector('#notif-toggle')
    this.notifMenu = this.el.querySelector('#notification-menu')
    
    // Profile Dropdown
    this.profileBtn = this.el.querySelector('#profile-toggle')
    this.profileMenu = this.el.querySelector('#profile-menu')

    // Sidebar Toggle Logic
    if (this.railToggle) {
      // Check stored preference
      const isCollapsed = localStorage.getItem('sidebar_collapsed') === 'true'
      if (isCollapsed) {
        this.appShell.classList.add('sidebar-collapsed')
      }

      this.railToggle.addEventListener('click', (e) => {
        e.preventDefault()
        this.appShell.classList.toggle('sidebar-collapsed')
        const currentCollapsed = this.appShell.classList.contains('sidebar-collapsed')
        localStorage.setItem('sidebar_collapsed', currentCollapsed)
      })
    }

    // Dropdown logic helper
    const setupDropdown = (btn, menu) => {
      if (!btn || !menu) return

      btn.addEventListener('click', (e) => {
        e.stopPropagation()
        const isHidden = menu.classList.contains('hidden')
        
        // Hide all menus first to act like an accordion
        if(this.notifMenu) this.notifMenu.classList.add('hidden')
        if(this.profileMenu) this.profileMenu.classList.add('hidden')

        if (isHidden) {
          menu.classList.remove('hidden')
          // Add entrance animation classes
          menu.classList.add('opacity-0', 'translate-y-2')
          requestAnimationFrame(() => {
            menu.classList.remove('opacity-0', 'translate-y-2')
            menu.classList.add('opacity-100', 'translate-y-0')
          })
        }
      })
    }

    setupDropdown(this.notifBtn, this.notifMenu)
    setupDropdown(this.profileBtn, this.profileMenu)

    // Close dropdowns on outside click
    document.addEventListener('click', (e) => {
      if (this.notifMenu && !this.notifMenu.contains(e.target) && !this.notifBtn.contains(e.target)) {
        this.notifMenu.classList.add('hidden')
      }
      if (this.profileMenu && !this.profileMenu.contains(e.target) && !this.profileBtn.contains(e.target)) {
        this.profileMenu.classList.add('hidden')
      }
    })

    // Command Palette Logic
    this.cmdBtn = this.el.querySelector('#search-trigger')
    this.cmdBackdrop = this.el.querySelector('#command-palette-backdrop')
    this.cmdModal = this.el.querySelector('#command-palette-modal')
    this.cmdInput = this.el.querySelector('#command-palette-input')

    const toggleCommandPalette = (show) => {
      if (!this.cmdBackdrop || !this.cmdModal) return
      
      if (show) {
        this.cmdBackdrop.classList.remove('hidden')
        // Hide other dropdowns
        if(this.notifMenu) this.notifMenu.classList.add('hidden')
        if(this.profileMenu) this.profileMenu.classList.add('hidden')

        // Animate in
        requestAnimationFrame(() => {
          this.cmdBackdrop.classList.remove('opacity-0')
          this.cmdBackdrop.classList.add('opacity-100')
          this.cmdModal.classList.remove('opacity-0', 'scale-95')
          this.cmdModal.classList.add('opacity-100', 'scale-100')
          setTimeout(() => this.cmdInput && this.cmdInput.focus(), 100)
        })
      } else {
        // Animate out
        this.cmdBackdrop.classList.remove('opacity-100')
        this.cmdBackdrop.classList.add('opacity-0')
        this.cmdModal.classList.remove('opacity-100', 'scale-100')
        this.cmdModal.classList.add('opacity-0', 'scale-95')
        setTimeout(() => this.cmdBackdrop.classList.add('hidden'), 200)
      }
    }

    if (this.cmdBtn) {
      this.cmdBtn.addEventListener('click', (e) => {
        e.preventDefault()
        toggleCommandPalette(true)
      })
    }

    // Global keyboard shortcut (Cmd+K or Ctrl+K)
    window.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        const isHidden = this.cmdBackdrop && this.cmdBackdrop.classList.contains('hidden')
        toggleCommandPalette(isHidden)
      } else if (e.key === 'Escape') {
        toggleCommandPalette(false)
      }
    })

    // Click outside backdrop to close
    if (this.cmdBackdrop) {
      this.cmdBackdrop.addEventListener('click', (e) => {
        if (e.target === this.cmdBackdrop) {
          toggleCommandPalette(false)
        }
      })
    }
  }
}

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

