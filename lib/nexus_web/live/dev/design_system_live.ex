defmodule NexusWeb.Dev.DesignSystemLive do
  @moduledoc """
  Design System Showcase — dev-only page at `/dev/design-system`.

  Renders every NexusComponents component with example data,
  serving as living documentation and a visual regression reference.
  """
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Design System",
        show_modal: false,
        search_value: "",
        toggle_on: false,
        show_notifications: false,
        show_profile: false,
        notifications: [
          %{message: "Invoice #3847 was received", time: "2 min ago"},
          %{message: "Statement upload completed", time: "15 min ago"},
          %{message: "Anomaly detected in Q4 batch", time: "1 hour ago"}
        ]
      )
      |> assign_new(:current_user, fn ->
        %Nexus.Identity.Projections.User{
          id: "dev-admin-id",
          display_name: "A. Freeman",
          role: "admin"
        }
      end)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_event("toggle-modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, !socket.assigns.show_modal)}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_event("search", %{"value" => value}, socket) do
    {:noreply, assign(socket, :search_value, value)}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply, assign(socket, :search_value, "")}
  end

  def handle_event("toggle-switch", _params, socket) do
    {:noreply, assign(socket, :toggle_on, !socket.assigns.toggle_on)}
  end

  def handle_event("toggle-notifications", _params, socket) do
    {:noreply, assign(socket, :show_notifications, !socket.assigns.show_notifications)}
  end

  def handle_event("toggle-profile", _params, socket) do
    {:noreply, assign(socket, :show_profile, !socket.assigns.show_profile)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.dark_page class="p-8">
      <div class="max-w-6xl mx-auto space-y-16">
        <%!-- Header --%>
        <header class="border-b border-white/[0.06] pb-8">
          <h1 class="text-3xl font-bold tracking-tight">Nexus Design System</h1>
          <p class="text-sm text-slate-500 mt-2">
            22 components · Dark institutional theme · Auto-imported
          </p>
        </header>

        <%!-- ═══ BUTTONS ═══ --%>
        <.section title="Buttons" subtitle="nx_button — 4 variants × 3 sizes">
          <div class="flex flex-wrap items-center gap-4">
            <.nx_button>Primary</.nx_button>
            <.nx_button variant="outline">Outline</.nx_button>
            <.nx_button variant="ghost">Ghost</.nx_button>
            <.nx_button variant="danger" icon="hero-trash">Danger</.nx_button>
            <.nx_button loading={true}>Loading</.nx_button>
          </div>
          <div class="flex flex-wrap items-center gap-4 mt-4">
            <.nx_button size="sm">Small</.nx_button>
            <.nx_button size="md">Medium</.nx_button>
            <.nx_button size="lg">Large</.nx_button>
          </div>
        </.section>

        <%!-- ═══ BADGES ═══ --%>
        <.section title="Badges" subtitle="badge — semantic status indicators">
          <div class="flex flex-wrap items-center gap-3">
            <.badge variant="info" label="Received" />
            <.badge variant="success" label="Ready" />
            <.badge variant="warning" label="Waiting" />
            <.badge variant="danger" label="Error" />
            <.badge variant="neutral" label="Archived" />
          </div>
        </.section>

        <%!-- ═══ STAT CARDS ═══ --%>
        <.section title="Stat Cards" subtitle="stat_card — KPI display with trend">
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <.stat_card
              label="Total Invoices"
              value="1,247"
              change="+23 today"
              trend="up"
              icon="hero-document-text"
            />
            <.stat_card
              label="Pending Review"
              value="34"
              change="12 overdue"
              trend="down"
              icon="hero-clock"
            />
            <.stat_card
              label="Matched"
              value="€2.4M"
              change="+8.2%"
              trend="up"
              icon="hero-check-circle"
            />
            <.stat_card
              label="At Risk"
              value="€340K"
              change="-2.1%"
              trend="down"
              icon="hero-exclamation-triangle"
            />
          </div>
        </.section>

        <%!-- ═══ DARK CARD ═══ --%>
        <.section title="Dark Card" subtitle="dark_card — primary container with optional title">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.dark_card class="p-6" title="Market Overview" subtitle="Last 24 hours">
              <div class="p-6 space-y-2">
                <.asset_item name="BTC/USD" price="68,432.12" change="+2.4%" />
                <.asset_item name="ETH/USD" price="3,821.50" change="-0.8%" />
                <.asset_item name="EUR/GBP" price="0.8542" change="+0.1%" />
              </div>
            </.dark_card>
            <.dark_card class="p-6" title="Quick Stats">
              <div class="p-6">
                <p class="text-2xl font-bold">€12.4M</p>
                <p class="text-xs text-slate-500 mt-1">Total portfolio value</p>
              </div>
            </.dark_card>
          </div>
        </.section>

        <%!-- ═══ DATA TABLE ═══ --%>
        <.section title="Data Table" subtitle="data_table — sortable dark table with actions">
          <.dark_card>
            <div class="p-2">
              <.data_table
                id="demo-invoices"
                rows={[
                  %{
                    id: "INV-3847",
                    vendor: "SAP AG",
                    amount: "€14,200.00",
                    status: "Matched",
                    status_variant: "success"
                  },
                  %{
                    id: "INV-3846",
                    vendor: "Oracle Corp",
                    amount: "€8,750.00",
                    status: "Waiting",
                    status_variant: "warning"
                  },
                  %{
                    id: "INV-3845",
                    vendor: "Bloomberg LP",
                    amount: "€32,100.00",
                    status: "Error",
                    status_variant: "danger"
                  },
                  %{
                    id: "INV-3844",
                    vendor: "Reuters",
                    amount: "€5,430.00",
                    status: "Received",
                    status_variant: "info"
                  }
                ]}
              >
                <:col :let={row} label="Invoice ID">
                  <span class="font-mono text-slate-300">{row.id}</span>
                </:col>
                <:col :let={row} label="Vendor">{row.vendor}</:col>
                <:col :let={row} label="Amount">
                  <span class="font-mono">{row.amount}</span>
                </:col>
                <:col :let={row} label="Status">
                  <.badge variant={row.status_variant} label={row.status} />
                </:col>
                <:action :let={_row}>
                  <.nx_button size="sm" variant="ghost">View</.nx_button>
                </:action>
              </.data_table>
              <.pagination showing={4} total={1247} has_more={true} />
            </div>
          </.dark_card>
        </.section>

        <%!-- ═══ LOADING DATA TABLE ═══ --%>
        <.section
          title="Loading DataGrid"
          subtitle="data_table — skeleton/shimmer state before data loads"
        >
          <.dark_card>
            <div class="p-2">
              <div class="animate-pulse">
                <%!-- Header row skeleton --%>
                <div class="flex items-center px-4 py-3 border-b border-[var(--nx-border)] bg-black/20">
                  <div class="h-3 bg-white/10 rounded w-24 mr-auto"></div>
                  <div class="h-3 bg-white/10 rounded w-32 mr-auto"></div>
                  <div class="h-3 bg-white/10 rounded w-20 mr-auto"></div>
                  <div class="h-3 bg-white/10 rounded w-16 mr-auto"></div>
                  <div class="h-3 bg-white/10 rounded w-8"></div>
                </div>
                <%!-- Body rows skeleton --%>
                <div class="divide-y divide-[var(--nx-border)]">
                  <div
                    :for={_ <- 1..5}
                    class="flex items-center px-4 py-4 hover:bg-[var(--nx-border)]/30 transition-colors"
                  >
                    <div class="w-1/4 pr-4">
                      <div class="h-4 bg-white/[0.06] rounded w-24 mb-1"></div>
                      <div class="h-3 bg-white/[0.03] rounded w-16"></div>
                    </div>
                    <div class="w-1/4 pr-4">
                      <div class="h-4 bg-white/[0.06] rounded w-32"></div>
                    </div>
                    <div class="w-1/4 pr-4 flex items-center">
                      <div class="h-4 bg-white/[0.06] rounded w-20"></div>
                    </div>
                    <div class="w-1/5 pr-4 flex items-center">
                      <div class="h-5 bg-white/[0.08] rounded-full w-16"></div>
                    </div>
                    <div class="w-12 flex justify-end">
                      <div class="h-6 bg-white/[0.04] rounded w-10"></div>
                    </div>
                  </div>
                </div>
              </div>
              <%!-- Pagination skeleton --%>
              <div class="flex items-center justify-between px-4 py-3 border-t border-[var(--nx-border)] opacity-50">
                <div class="animate-pulse h-4 bg-white/5 rounded w-16"></div>
                <div class="animate-pulse h-4 bg-white/5 rounded w-24"></div>
                <div class="animate-pulse flex gap-2">
                  <div class="h-button bg-white/5 rounded px-3 py-1 w-16"></div>
                  <div class="h-button bg-white/5 rounded px-3 py-1 w-16"></div>
                </div>
              </div>
            </div>
          </.dark_card>
        </.section>

        <%!-- ═══ FORM INPUTS ═══ --%>
        <.section title="Form Inputs" subtitle="nx_input, nx_select, search_input, toggle">
          <.dark_card class="p-8">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <.nx_input label="Invoice Reference" placeholder="INV-0000" icon="hero-hashtag" />
              <.nx_input label="Amount" type="number" placeholder="0.00" icon="hero-currency-euro" />
              <.nx_select
                label="Currency"
                options={["EUR", "USD", "GBP", "CHF"]}
                prompt="Select currency"
              />
              <.nx_input
                label="With Error"
                placeholder="bad input"
                errors={["This field is required"]}
              />
            </div>
            <div class="mt-6 space-y-4">
              <.search_input value={@search_value} placeholder="Search invoices..." />
              <.toggle
                enabled={@toggle_on}
                label="Enable automatic matching"
                on_toggle="toggle-switch"
              />
            </div>
          </.dark_card>
        </.section>

        <%!-- ═══ TOASTS ═══ --%>
        <.section title="Toasts" subtitle="toast — notification alerts">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.toast
              kind="success"
              title="Invoice received"
              message="Invoice #3847 was received successfully."
            />
            <.toast kind="error" title="Upload failed" message="Could not parse your bank statement." />
            <.toast kind="warning" title="Rate limit" message="SAP sandbox: 3 of 5 calls remaining." />
            <.toast kind="info" title="Processing" message="Your statement is being analyzed." />
          </div>
        </.section>

        <%!-- ═══ MODAL ═══ --%>
        <.section title="Modal" subtitle="modal — centered overlay with backdrop">
          <.nx_button phx-click="toggle-modal" icon="hero-eye">Open Modal</.nx_button>
          <.modal id="demo-modal" show={@show_modal} on_close="close-modal">
            <div class="text-center space-y-4">
              <div class="w-14 h-14 rounded-2xl bg-indigo-500/15 flex items-center justify-center mx-auto">
                <span class="hero-shield-check w-7 h-7 text-indigo-400"></span>
              </div>
              <h2 class="text-xl font-bold">Confirm Your Identity</h2>
              <p class="text-sm text-slate-400">
                This operation requires step-up verification for trades over €100,000.
              </p>
              <div class="flex gap-3 justify-center pt-2">
                <.nx_button variant="ghost" phx-click="close-modal">Cancel</.nx_button>
                <.nx_button phx-click="close-modal">Verify Now</.nx_button>
              </div>
            </div>
          </.modal>
        </.section>

        <%!-- ═══ LOADING SKELETONS ═══ --%>
        <.section title="Loading Skeletons" subtitle="loading_skeleton — animated placeholders">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="space-y-3">
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold">Lines</p>
              <.loading_skeleton type="line" count={4} />
            </div>
            <div>
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold mb-3">
                Card
              </p>
              <.loading_skeleton type="card" />
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
            <div>
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold mb-3">
                Chart
              </p>
              <.loading_skeleton type="chart" />
            </div>
            <div>
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold mb-3">
                Table
              </p>
              <.loading_skeleton type="table" />
            </div>
          </div>
        </.section>

        <%!-- ═══ SPINNER ═══ --%>
        <.section title="Spinners" subtitle="spinner — loading indicator">
          <div class="flex items-center gap-6">
            <.spinner size="sm" />
            <.spinner size="md" />
            <.spinner size="lg" />
          </div>
        </.section>

        <%!-- ═══ SESSION INDICATOR ═══ --%>
        <.section title="Session Indicator" subtitle="session_indicator — connection status">
          <div class="flex items-center gap-8">
            <.session_indicator status="connected" />
            <.session_indicator status="reconnecting" />
            <.session_indicator status="disconnected" />
          </div>
        </.section>

        <%!-- ═══ EMPTY STATE ═══ --%>
        <.section title="Empty State" subtitle="empty_state — no-data placeholder">
          <.dark_card>
            <.empty_state
              icon="hero-document-text"
              title="No invoices yet"
              message="Invoices will appear here when they're received from your ERP system."
            />
          </.dark_card>
        </.section>

        <%!-- ═══ SPECIALIZED ═══ --%>
        <.section title="Specialized" subtitle="notification_dropdown, profile_menu">
          <div class="flex items-center gap-8">
            <div>
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold mb-3">
                Notification Bell
              </p>
              <.notification_dropdown
                notifications={@notifications}
                show={@show_notifications}
                on_toggle="toggle-notifications"
              />
            </div>
            <div>
              <p class="text-[10px] uppercase tracking-widest text-slate-500 font-semibold mb-3">
                Profile Menu
              </p>
              <.profile_menu
                user_name="Elena"
                session_id="3F8A"
                show={@show_profile}
                on_toggle="toggle-profile"
              />
            </div>
          </div>
        </.section>

        <%!-- Footer --%>
        <footer class="text-center text-xs text-slate-600 py-8 border-t border-white/[0.06]">
          Nexus Design System · {length(component_list())} components · Dev only
        </footer>
      </div>
    </.dark_page>
    """
  end

  # ── Section wrapper ──
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <section>
      <div class="mb-6">
        <h2 class="text-lg font-bold">{@title}</h2>
        <p :if={@subtitle} class="text-xs text-slate-500 mt-0.5">{@subtitle}</p>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  defp component_list do
    ~w(dark_page app_shell sidebar topbar dark_card stat_card data_table pagination badge
       asset_item empty_state nx_input nx_select toggle search_input file_upload_zone
       nx_button modal toast loading_skeleton spinner session_indicator
       notification_dropdown profile_menu)
  end
end
