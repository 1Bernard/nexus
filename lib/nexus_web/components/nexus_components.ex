defmodule NexusWeb.NexusComponents do
  @moduledoc """
  Nexus Design System — Shared Component Library.

  All components follow the dark institutional aesthetic defined in
  `nexus-ux-flow.md`. Auto-imported via `html_helpers/0` in `NexusWeb`.

  ## Categories

  1. **Layout** — dark_page, app_shell, sidebar, topbar
  2. **Data Display** — dark_card, stat_card, data_table, pagination, badge, asset_item, empty_state
  3. **Forms & Inputs** — nx_input, nx_select, toggle, search_input, file_upload_zone
  4. **Actions** — nx_button
  5. **Feedback & Overlays** — modal, toast, loading_skeleton, spinner, session_indicator
  6. **Specialized** — notification_dropdown, profile_menu
  """
  use Phoenix.Component

  # ══════════════════════════════════════════════════════════════
  # 1. LAYOUT
  # ══════════════════════════════════════════════════════════════

  @doc """
  Full-page dark wrapper used by all Nexus views.

  ## Examples

      <.dark_page>
        <h1>Content here</h1>
      </.dark_page>
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dark_page(assigns) do
    ~H"""
    <div class={[
      "min-h-screen bg-[#0B0E14] text-slate-100 font-sans selection:bg-indigo-500/40",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Authenticated app shell — sidebar + topbar + content area.
  Used as the layout wrapper for all post-login pages.

  ## Examples

      <.app_shell current_path={@current_path} session_status="connected">
        <:topbar_title>Dashboard</:topbar_title>
        <:content>
          ... page content ...
        </:content>
      </.app_shell>
  """
  attr :current_path, :string, default: "/dashboard"
  attr :session_status, :string, default: "connected"
  attr :session_id, :string, default: "3F8A"
  slot :topbar_title
  slot :topbar_subtitle
  slot :content, required: true

  def app_shell(assigns) do
    ~H"""
    <div
      id="app-shell"
      phx-hook="NavInteractions"
      class="min-h-screen bg-[var(--nx-bg)] text-slate-100 font-sans selection:bg-indigo-500/40 flex transition-[width] duration-300 [&.sidebar-collapsed]:[--nx-sidebar-w:88px]"
    >
      <.sidebar
        current_path={@current_path}
        session_status={@session_status}
        session_id={@session_id}
      />

      <div class="flex-1 ml-[var(--nx-sidebar-w)] flex flex-col min-h-screen transition-all duration-300">
        <.topbar>
          <:title>{render_slot(@topbar_title)}</:title>
          <:subtitle>{render_slot(@topbar_subtitle)}</:subtitle>
        </.topbar>

        <main class="flex-1 p-8 overflow-y-auto">
          {render_slot(@content)}
        </main>
      </div>

      <%!-- Global Command Palette --%>
      <.command_palette />
    </div>
    """
  end

  @doc """
  Persistent left sidebar with navigation links, session status, and trust footer.
  """
  attr :current_path, :string, default: "/dashboard"
  attr :session_status, :string, default: "connected"
  attr :session_id, :string, default: "3F8A"

  def sidebar(assigns) do
    core_nav = [
      %{path: "/dashboard", label: "Dashboard", icon: "hero-chart-bar-square"},
      %{path: "/intelligence", label: "Smart Insights", icon: "hero-sparkles"}
    ]

    ops_nav = [
      %{path: "/invoices", label: "Your Invoices", icon: "hero-document-text"},
      %{path: "/statements", label: "Upload Statements", icon: "hero-arrow-up-tray"}
    ]

    assigns =
      assigns
      |> assign(:core_nav, core_nav)
      |> assign(:ops_nav, ops_nav)

    ~H"""
    <aside class="fixed top-0 left-0 h-screen w-[var(--nx-sidebar-w)] bg-[var(--nx-surface)] border-r border-[var(--nx-border)] flex flex-col z-40 overflow-hidden transition-[width] duration-300 [&_#rail-logo]:[.sidebar-collapsed_&]:block [&_#full-logo]:[.sidebar-collapsed_&]:hidden [&_.nav-label]:[.sidebar-collapsed_&]:hidden [&_.nav-header]:[.sidebar-collapsed_&]:opacity-0 [&_#session-full]:[.sidebar-collapsed_&]:hidden [&_#session-rail]:[.sidebar-collapsed_&]:flex">
      <%!-- Logo --%>
      <div class="px-6 py-5 border-b border-[var(--nx-border)] shrink-0 h-[var(--nx-topbar-h)] flex items-center">
        <div id="full-logo" class="flex items-center gap-2.5 transition-opacity duration-200">
          <div class="w-8 h-8 rounded-xl bg-indigo-500/15 flex items-center justify-center border border-indigo-500/20 shrink-0">
            <span class="text-indigo-400 font-bold text-sm">◆</span>
          </div>
          <span class="text-base font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-slate-400">
            NEXUS
          </span>
        </div>
        <div
          id="rail-logo"
          class="hidden items-center justify-center w-full transition-opacity duration-200"
        >
          <div class="w-8 h-8 rounded-xl bg-indigo-500/15 flex items-center justify-center border border-indigo-500/20 shrink-0">
            <span class="text-indigo-400 font-bold text-sm">◆</span>
          </div>
        </div>
      </div>

      <%!-- Navigation --%>
      <nav class="flex-1 px-3 py-6 space-y-8 overflow-y-auto hidden-scrollbar">
        <%!-- Core Group --%>
        <div>
          <h3 class="nav-header px-3 text-[10px] font-bold text-slate-500 uppercase tracking-[0.15em] mb-3 transition-opacity duration-200">
            Core
          </h3>
          <div class="space-y-1">
            <.link
              :for={item <- @core_nav}
              navigate={item.path}
              title={item.label}
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-all duration-200 group/item overflow-hidden",
                if(item.path == @current_path,
                  do: "bg-indigo-500/10 text-indigo-300 border-l-2 border-indigo-500 font-medium",
                  else:
                    "text-slate-400 hover:text-slate-200 hover:bg-white/[0.04] border-l-2 border-transparent"
                )
              ]}
            >
              <span class={[
                item.icon,
                "w-5 h-5 shrink-0 transition-colors"
              ]}>
              </span>
              <span class="nav-label whitespace-nowrap transition-opacity duration-200">
                {item.label}
              </span>
            </.link>
          </div>
        </div>

        <%!-- Operations Group --%>
        <div>
          <h3 class="nav-header px-3 text-[10px] font-bold text-slate-500 uppercase tracking-[0.15em] mb-3 transition-opacity duration-200">
            Operations
          </h3>
          <div class="space-y-1">
            <.link
              :for={item <- @ops_nav}
              navigate={item.path}
              title={item.label}
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-all duration-200 group/item overflow-hidden",
                if(item.path == @current_path,
                  do: "bg-indigo-500/10 text-indigo-300 border-l-2 border-indigo-500 font-medium",
                  else:
                    "text-slate-400 hover:text-slate-200 hover:bg-white/[0.04] border-l-2 border-transparent"
                )
              ]}
            >
              <span class={[
                item.icon,
                "w-5 h-5 shrink-0 transition-colors"
              ]}>
              </span>
              <span class="nav-label whitespace-nowrap transition-opacity duration-200">
                {item.label}
              </span>
            </.link>
          </div>
        </div>
      </nav>

      <%!-- Session Status Footer & Rail Toggle --%>
      <div class="border-t border-[var(--nx-border)] bg-slate-900/20 shrink-0">
        <div
          id="session-full"
          class="px-5 py-4 space-y-2 border-b border-[var(--nx-border)] transition-all duration-200"
        >
          <.session_indicator status={@session_status} />
          <p class="text-[10px] text-slate-600 font-mono whitespace-nowrap">
            Session: {@session_id}...
          </p>
          <div class="flex items-center gap-1.5 mt-1">
            <span class="hero-shield-check w-3 h-3 text-emerald-500/70 shrink-0"></span>
            <p class="text-[9px] text-slate-500 uppercase tracking-wider font-medium whitespace-nowrap">
              Auth: MFA Enabled
            </p>
          </div>
        </div>

        <div
          id="session-rail"
          class="hidden py-4 border-b border-[var(--nx-border)] items-center justify-center transition-all duration-200"
        >
          <.session_indicator status={@session_status} />
        </div>

        <button
          id="rail-toggle"
          class="w-full flex items-center justify-center py-3 text-slate-500 hover:text-slate-300 hover:bg-white/[0.02] transition-colors cursor-pointer group/toggle"
          title="Toggle Sidebar"
        >
          <span class="hero-chevron-double-left w-4 h-4 group-hover/toggle:-translate-x-1 transition-transform [.sidebar-collapsed_&]:rotate-180 [.sidebar-collapsed_&]:group-hover/toggle:translate-x-1">
          </span>
        </button>
      </div>
    </aside>
    """
  end

  @doc """
  Top bar with page title, subtitle, and session badge.
  """
  slot :title
  slot :subtitle
  slot :actions

  def topbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-30 h-[var(--nx-topbar-h)] border-b border-[var(--nx-border)] bg-[var(--nx-surface)]/80 backdrop-blur-md flex items-center justify-between px-8 shrink-0">
      <%!-- Left: Dynamic Breadcrumbs & Title --%>
      <div class="flex items-center gap-3">
        <div class="hidden md:flex items-center gap-2 text-sm mr-2">
          <span class="text-slate-500 font-medium hover:text-slate-300 cursor-pointer transition-colors">
            Nexus
          </span>
          <span class="hero-chevron-right w-3 h-3 text-slate-600"></span>
          <span class="text-slate-500 font-medium hover:text-slate-300 cursor-pointer transition-colors">
            Treasury
          </span>
          <span class="hero-chevron-right w-3 h-3 text-slate-600"></span>
        </div>
        <h1 class="text-lg font-bold tracking-tight text-slate-200">{render_slot(@title)}</h1>
        <p
          :if={@subtitle != []}
          class="text-xs text-slate-500 hidden lg:block ml-2 pl-2 border-l border-white/10"
        >
          {render_slot(@subtitle)}
        </p>
      </div>

      <%!-- Middle: Global Command Menu (Search) --%>
      <div class="flex-1 max-w-lg mx-8 hidden lg:block">
        <button
          id="search-trigger"
          class="relative group w-full text-left flex items-center justify-between border border-slate-700/50 rounded-lg bg-slate-900/40 text-slate-400 hover:bg-[var(--nx-surface)] hover:text-slate-300 transition-all shadow-inner py-1.5 pl-3 pr-2 cursor-pointer focus:outline-none focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 ring-offset-[var(--nx-surface)]"
        >
          <div class="flex items-center gap-2">
            <span class="hero-magnifying-glass w-4 h-4 text-slate-500 group-hover:text-indigo-400 transition-colors">
            </span>
            <span class="text-sm">Search transactions, invoices...</span>
          </div>
          <span class="text-[10px] text-slate-400 font-mono border border-slate-700 rounded px-1.5 py-0.5 bg-slate-800 shadow-sm shrink-0">
            ⌘K
          </span>
        </button>
      </div>

      <%!-- Right: Actions & User Profile --%>
      <div class="flex items-center gap-5">
        <div :if={@actions != []} class="flex items-center gap-2">
          {render_slot(@actions)}
        </div>

        <div class="flex items-center gap-5 pl-5 border-l border-[var(--nx-border)]">
          <%!-- Notifications --%>
          <div class="relative">
            <button
              id="notif-toggle"
              class="relative text-slate-400 hover:text-indigo-300 transition-colors cursor-pointer group"
            >
              <span class="hero-bell w-5 h-5"></span>
              <span class="absolute top-0 right-0.5 w-2 h-2 rounded-full bg-rose-500 ring-2 ring-[var(--nx-surface)]">
              </span>
            </button>

            <%!-- Dropdown Menu --%>
            <div
              id="notification-menu"
              class="hidden absolute top-full right-0 mt-3 w-80 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl shadow-xl shadow-black/80 ring-1 ring-white/5 overflow-hidden z-50"
            >
              <div class="px-4 py-3 border-b border-[var(--nx-border)] flex justify-between items-center bg-slate-800/20">
                <h3 class="text-xs font-bold text-slate-200 uppercase tracking-wider">
                  Notifications
                </h3>
                <span class="text-[10px] text-indigo-400 hover:text-indigo-300 cursor-pointer">
                  Mark all read
                </span>
              </div>
              <div class="p-2 max-h-[300px] overflow-y-auto hidden-scrollbar">
                <div class="px-3 py-3 hover:bg-white/[0.02] rounded-xl transition-colors cursor-pointer flex gap-3">
                  <div class="w-2 h-2 rounded-full bg-rose-500 mt-1.5 shrink-0"></div>
                  <div>
                    <p class="text-[11px] text-slate-200">Critical Limit Approached</p>
                    <p class="text-[10px] text-slate-500 mt-0.5">
                      London / JPY exposure exceeds limit.
                    </p>
                  </div>
                </div>
                <div class="px-3 py-3 hover:bg-white/[0.02] rounded-xl transition-colors cursor-pointer flex gap-3 opacity-60">
                  <div class="w-2 h-2 rounded-full bg-transparent border border-slate-600 mt-1.5 shrink-0">
                  </div>
                  <div>
                    <p class="text-[11px] text-slate-200">Payment Matched</p>
                    <p class="text-[10px] text-slate-500 mt-0.5">Invoice #3842 fully reconciled.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- User Profile Dropdown Toggle --%>
          <div class="relative">
            <div id="profile-toggle" class="flex items-center gap-3 cursor-pointer group">
              <div class="text-right hidden sm:block">
                <p class="text-xs font-bold text-slate-200 group-hover:text-white transition-colors">
                  A. Freeman
                </p>
                <div class="flex items-center gap-1.5 justify-end mt-0.5">
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                  <p class="text-[9px] text-emerald-400/80 font-medium uppercase tracking-wider">
                    CFO
                  </p>
                </div>
              </div>
              <div class="w-8 h-8 rounded-full bg-slate-800 border border-[var(--nx-border)] flex items-center justify-center overflow-hidden flex-shrink-0 group-hover:bg-slate-700 transition-colors">
                <span class="text-xs font-bold text-slate-300">AF</span>
              </div>
              <span class="hero-chevron-down w-3 h-3 text-slate-500 group-hover:text-slate-300 transition-colors hidden sm:block">
              </span>
            </div>

            <%!-- Profile Menu --%>
            <div
              id="profile-menu"
              class="hidden absolute top-full right-0 mt-3 w-56 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl shadow-xl shadow-black/80 ring-1 ring-white/5 overflow-hidden z-50"
            >
              <div class="p-4 border-b border-[var(--nx-border)] bg-slate-800/20">
                <p class="text-sm font-bold text-white">Alexander Freeman</p>
                <p class="text-xs text-slate-500">Chief Financial Officer</p>
              </div>
              <div class="p-2 space-y-0.5">
                <a
                  href="#"
                  class="flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04] rounded-lg transition-colors"
                >
                  <span class="hero-cog-8-tooth w-4 h-4 text-slate-500"></span> Settings
                </a>
                <a
                  href="#"
                  class="flex items-center gap-3 px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-white/[0.04] rounded-lg transition-colors"
                >
                  <span class="hero-shield-check w-4 h-4 text-slate-500"></span> Security
                </a>
                <div class="my-1 border-t border-[var(--nx-border)]"></div>
                <.link
                  href="/auth/logout"
                  method="delete"
                  class="flex items-center gap-3 px-3 py-2 text-sm text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 rounded-lg transition-colors"
                >
                  <span class="hero-arrow-right-on-rectangle w-4 h-4"></span> End Session
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 2. DATA DISPLAY
  # ══════════════════════════════════════════════════════════════

  @doc """
  Dark card panel — the primary container for content sections.

  ## Examples

      <.dark_card>
        <h2>Market Activity</h2>
      </.dark_card>

      <.dark_card class="p-8" title="Recent Activity">
        <p>Content</p>
      </.dark_card>
  """
  attr :class, :string, default: nil
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true
  slot :header_actions

  def dark_card(assigns) do
    ~H"""
    <div class={[
      "bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-[var(--nx-radius-lg)]",
      @class
    ]}>
      <div :if={@title} class="flex items-center justify-between px-6 pt-5 pb-0">
        <div>
          <h3 class="text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-400">
            {@title}
          </h3>
          <p :if={@subtitle} class="text-xs text-slate-600 mt-0.5">{@subtitle}</p>
        </div>
        <div :if={@header_actions != []}>{render_slot(@header_actions)}</div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Stat card with label, value, optional change indicator and icon.

  ## Examples

      <.stat_card label="Total Invoices" value="1,247" change="+23 today" trend="up" />
      <.stat_card label="At Risk" value="€340K" change="-2.1%" trend="down" icon="hero-exclamation-triangle" />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :change, :string, default: nil
  attr :trend, :string, default: nil, values: ["up", "down", nil]
  attr :icon, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl p-5 hover:border-[var(--nx-border-hover)] transition-colors">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-500">{@label}</p>
          <p class="text-2xl font-bold tracking-tight mt-1">{@value}</p>
          <p
            :if={@change}
            class={[
              "text-xs font-medium mt-1",
              @trend == "up" && "text-emerald-400",
              @trend == "down" && "text-rose-400",
              is_nil(@trend) && "text-slate-400"
            ]}
          >
            <span :if={@trend == "up"}>↑ </span>
            <span :if={@trend == "down"}>↓ </span>
            {@change}
          </p>
        </div>
        <div :if={@icon} class="w-10 h-10 rounded-xl bg-white/[0.04] flex items-center justify-center">
          <span class={[@icon, "w-5 h-5 text-slate-400"]}></span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Dark-themed data table with column slots and optional row click.

  ## Examples

      <.data_table id="invoices" rows={@invoices}>
        <:col :let={inv} label="Invoice ID">{inv.id}</:col>
        <:col :let={inv} label="Amount">{inv.amount}</:col>
        <:action :let={inv}>
          <.nx_button size="sm" variant="ghost">View</.nx_button>
        </:action>
      </.data_table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :row_click, :any, default: nil

  attr :row_item, :any, default: &Function.identity/1

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action

  def data_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full">
        <thead>
          <tr class="border-b border-[var(--nx-border)]">
            <th
              :for={col <- @col}
              class="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-500"
            >
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-4 py-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={[
              "border-b border-[var(--nx-border)] hover:bg-white/[0.02] transition-colors",
              @row_click && "cursor-pointer"
            ]}
            phx-click={@row_click && @row_click.(row)}
          >
            <td :for={col <- @col} class={["px-4 py-3.5 text-sm", col[:class]]}>
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-4 py-3.5 text-right">
              <div class="flex justify-end gap-2">
                {render_slot(@action, @row_item.(row))}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Cursor-based "Load more" pagination with count indicator.

  ## Examples

      <.pagination showing={25} total={1247} has_more={true} on_load_more="load-more" />
  """
  attr :showing, :integer, required: true
  attr :total, :integer, required: true
  attr :has_more, :boolean, default: true
  attr :on_load_more, :string, default: "load-more"

  def pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between pt-4 px-4">
      <p class="text-xs text-slate-500">
        Showing <span class="text-slate-300 font-medium">{@showing}</span>
        of <span class="text-slate-300 font-medium">{@total}</span>
      </p>
      <button
        :if={@has_more}
        phx-click={@on_load_more}
        class="text-xs text-indigo-400 hover:text-indigo-300 font-medium transition-colors flex items-center gap-1"
      >
        Load more <span class="hero-chevron-down w-3 h-3"></span>
      </button>
    </div>
    """
  end

  @doc """
  Status badge with semantic variants.

  ## Examples

      <.badge variant="success" label="Ready" />
      <.badge variant="danger" label="Error" />
      <.badge variant="warning" label="Waiting" />
      <.badge variant="info" label="Received" />
  """
  attr :variant, :string, default: "info", values: ~w(info success warning danger neutral)
  attr :label, :string, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-semibold uppercase tracking-wider",
      @variant == "info" && "bg-indigo-500/15 text-indigo-300",
      @variant == "success" && "bg-emerald-500/15 text-emerald-300",
      @variant == "warning" && "bg-amber-500/15 text-amber-300",
      @variant == "danger" && "bg-rose-500/15 text-rose-300",
      @variant == "neutral" && "bg-white/[0.06] text-slate-400"
    ]}>
      <span class={[
        "w-1.5 h-1.5 rounded-full",
        @variant == "info" && "bg-indigo-400",
        @variant == "success" && "bg-emerald-400",
        @variant == "warning" && "bg-amber-400",
        @variant == "danger" && "bg-rose-400",
        @variant == "neutral" && "bg-slate-500"
      ]}>
      </span>
      {@label}
    </span>
    """
  end

  @doc """
  Currency pair row with name, price, and change indicator.

  ## Examples

      <.asset_item name="BTC/USD" price="68,432.12" change="+2.4%" />
  """
  attr :name, :string, required: true
  attr :price, :string, required: true
  attr :change, :string, required: true

  def asset_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-3 rounded-2xl bg-white/[0.02] hover:bg-white/[0.04] transition-colors group cursor-pointer border border-transparent hover:border-white/5">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-xl bg-white/5 flex items-center justify-center text-xs font-bold text-slate-400">
          {@name |> String.split("/") |> List.first()}
        </div>
        <span class="text-sm font-medium">{@name}</span>
      </div>
      <div class="text-right">
        <div class="text-sm font-mono">{@price}</div>
        <div class={[
          "text-[10px] font-bold",
          if(@change =~ "+", do: "text-emerald-400", else: "text-rose-400")
        ]}>
          {@change}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Empty state placeholder with icon and message.

  ## Examples

      <.empty_state icon="hero-document-text" title="No invoices yet" message="Invoices will appear here when they're received." />
  """
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :message, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 text-center">
      <div class="w-16 h-16 rounded-2xl bg-white/[0.04] flex items-center justify-center mb-4">
        <span class={[@icon, "w-8 h-8 text-slate-600"]}></span>
      </div>
      <p class="text-sm font-medium text-slate-400">{@title}</p>
      <p :if={@message} class="text-xs text-slate-600 mt-1 max-w-xs">{@message}</p>
    </div>
    """
  end

  @doc """
  Top-level dashboard KPI card with an optional animated progress bar at the bottom.

  ## Examples

      <.kpi_card title="Successfully Matched" value="847" label="Transactions" color="emerald" progress />
  """
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :color, :string, default: "emerald", values: ~w(emerald amber rose indigo)
  attr :progress, :boolean, default: false

  def kpi_card(assigns) do
    ~H"""
    <.dark_card class="p-5 flex flex-col justify-between relative overflow-hidden">
      <p class="text-[10px] text-slate-500 uppercase tracking-[0.1em]">{@title}</p>
      <div class="mt-2 flex items-baseline gap-2">
        <p class={[
          "text-2xl font-mono tracking-tight",
          @color == "emerald" && "text-emerald-400",
          @color == "amber" && "text-amber-400",
          @color == "rose" && "text-rose-400",
          @color == "indigo" && "text-indigo-400"
        ]}>
          {@value}
        </p>
        <p class="text-[10px] text-slate-500 uppercase">{@label}</p>
      </div>
      <div
        :if={@progress}
        class={[
          "absolute bottom-0 left-0 w-full h-1",
          @color == "emerald" && "bg-emerald-500/20",
          @color == "amber" && "bg-amber-500/20",
          @color == "rose" && "bg-rose-500/20",
          @color == "indigo" && "bg-indigo-500/20"
        ]}
      >
        <div class={[
          "h-full w-full",
          @color == "emerald" && "bg-emerald-500",
          @color == "amber" && "bg-amber-500",
          @color == "rose" && "bg-rose-500",
          @color == "indigo" && "bg-indigo-500"
        ]}>
        </div>
      </div>
    </.dark_card>
    """
  end

  @doc """
  Segmented control for selecting timeframes (e.g. 1H, 1D, 30D).

  ## Examples

      <.timeframe_selector options={["1H", "4H", "1D", "1W"]} active="1D" on_change="set_tf" />
  """
  attr :options, :list, required: true
  attr :active, :string, required: true
  attr :on_change, :string, required: true
  attr :variant, :string, default: "subtle", values: ~w(subtle solid)

  def timeframe_selector(assigns) do
    ~H"""
    <div class={[
      "flex gap-1 text-[10px] font-medium text-slate-400",
      @variant == "solid" && "bg-slate-900/30 p-0.5 rounded-lg border border-slate-800/50"
    ]}>
      <%= for option <- @options do %>
        <button
          phx-click={@on_change}
          phx-value-tf={option}
          class={[
            "px-2 py-1 rounded-md transition-colors",
            @variant == "subtle" && @active == option && "bg-white/5 text-white border border-white/5",
            @variant == "subtle" && @active != option &&
              "cursor-pointer hover:text-white border border-transparent",
            @variant == "solid" && @active == option &&
              "bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 shadow-[0_0_10px_rgba(99,102,241,0.1)]",
            @variant == "solid" && @active != option &&
              "hover:text-white border border-transparent cursor-pointer"
          ]}
        >
          {option}
        </button>
      <% end %>
    </div>
    """
  end

  @doc """
  A single row in the Recent Activity feed.

  ## Examples

      <.activity_item
        icon="hero-check-circle"
        color="emerald"
        title="Payment matched"
        id_str="#3842"
        time_ago="15 min ago"
      />
  """
  attr :icon, :string, required: true
  attr :color, :string, default: "indigo", values: ~w(indigo emerald amber rose white)
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :id_str, :string, default: nil
  attr :amount_str, :string, default: nil
  attr :time_ago, :string, required: true

  def activity_item(assigns) do
    ~H"""
    <div class="flex items-start gap-4 relative">
      <div class={[
        "w-6 h-6 rounded-full border flex items-center justify-center shrink-0 z-10 mt-0.5",
        @color == "indigo" && "bg-indigo-500/20 border-indigo-500/30",
        @color == "emerald" && "bg-emerald-500/20 border-emerald-500/30",
        @color == "amber" && "bg-amber-500/20 border-amber-500/30",
        @color == "rose" && "bg-rose-500/20 border-rose-500/30",
        @color == "white" && "bg-white/10 border-white/20"
      ]}>
        <span class={[
          @icon,
          "w-3 h-3",
          @color == "indigo" && "text-indigo-400",
          @color == "emerald" && "text-emerald-400",
          @color == "amber" && "text-amber-400",
          @color == "rose" && "text-rose-400",
          @color == "white" && "text-slate-300"
        ]}>
        </span>
      </div>
      <div class="flex-1">
        <p class={[
          "text-sm",
          (@color == "indigo" || @color == "emerald" || @color == "white") && "text-slate-200",
          @color == "amber" && "text-amber-300",
          @color == "rose" && "text-rose-300"
        ]}>
          {@title}
          <span :if={@id_str} class="text-white font-mono">{@id_str}</span>
          <span :if={@amount_str} class="text-emerald-400 font-mono">({@amount_str})</span>
        </p>
        <p :if={@subtitle} class="text-[11px] text-slate-400 font-mono mt-0.5">
          {@subtitle}
        </p>
        <p class="text-[10px] text-slate-400 mt-1 uppercase font-medium tracking-wider">
          {@time_ago}
        </p>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 3. FORMS & INPUTS
  # ══════════════════════════════════════════════════════════════

  @doc """
  Dark-themed text input with optional label and icon.

  ## Examples

      <.nx_input field={@form[:email]} label="Email" placeholder="you@company.com" icon="hero-envelope" />
      <.nx_input field={@form[:amount]} type="number" label="Amount" />
  """
  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :icon, :string, default: nil
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(disabled readonly required min max step autocomplete)

  def nx_input(assigns) do
    assigns =
      if assigns.field do
        field = assigns.field
        errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

        assigns
        |> assign(field: nil, id: assigns.id || field.id)
        |> assign(:name, field.name)
        |> assign_new(:value, fn -> field.value end)
        |> assign(:errors, Enum.map(errors, &translate_error/1))
      else
        assigns
      end

    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} class="text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-500">
        {@label}
      </label>
      <div class="relative">
        <span
          :if={@icon}
          class={[@icon, "absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500"]}
        >
        </span>
        <input
          type={@type}
          id={@id}
          name={@name}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          placeholder={@placeholder}
          class={[
            "w-full bg-white/[0.04] border border-[var(--nx-border)] rounded-xl px-4 py-2.5 text-sm text-slate-100 placeholder-slate-600",
            "focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/30 transition-all",
            @icon && "pl-10",
            @errors != [] && "border-rose-500/50"
          ]}
          {@rest}
        />
      </div>
      <p :for={msg <- @errors} class="text-xs text-rose-400 flex items-center gap-1">
        <span class="hero-exclamation-circle w-3.5 h-3.5"></span>
        {msg}
      </p>
    </div>
    """
  end

  @doc """
  Dark-themed select dropdown.

  ## Examples

      <.nx_select field={@form[:currency]} label="Currency" options={["EUR", "USD", "GBP"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :options, :list, required: true
  attr :prompt, :string, default: nil
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(disabled required)

  def nx_select(assigns) do
    assigns =
      if assigns.field do
        field = assigns.field
        errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

        assigns
        |> assign(field: nil, id: assigns.id || field.id)
        |> assign(:name, field.name)
        |> assign_new(:value, fn -> field.value end)
        |> assign(:errors, Enum.map(errors, &translate_error/1))
      else
        assigns
      end

    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} class="text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-500">
        {@label}
      </label>
      <select
        id={@id}
        name={@name}
        class={[
          "w-full bg-white/[0.04] border border-[var(--nx-border)] rounded-xl px-4 py-2.5 text-sm text-slate-100",
          "focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/30 transition-all appearance-none",
          @errors != [] && "border-rose-500/50"
        ]}
        {@rest}
      >
        <option :if={@prompt} value="" class="bg-[var(--nx-surface)]">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :for={msg <- @errors} class="text-xs text-rose-400 flex items-center gap-1">
        <span class="hero-exclamation-circle w-3.5 h-3.5"></span>
        {msg}
      </p>
    </div>
    """
  end

  @doc """
  Toggle switch with label.

  ## Examples

      <.toggle field={@form[:enabled]} label="Enable notifications" />
      <.toggle enabled={true} label="Dark mode" on_toggle="toggle-dark" />
  """
  attr :enabled, :boolean, default: false
  attr :label, :string, default: nil
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :on_toggle, :string, default: nil
  attr :rest, :global, include: ~w(disabled)

  def toggle(assigns) do
    assigns =
      if assigns.field do
        field = assigns.field

        assigns
        |> assign(:enabled, Phoenix.HTML.Form.normalize_value("checkbox", field.value))
        |> assign(:name, field.name)
        |> assign(:id, field.id)
      else
        assigns
        |> assign_new(:name, fn -> nil end)
        |> assign_new(:id, fn -> nil end)
      end

    ~H"""
    <label class="flex items-center gap-3 cursor-pointer group">
      <input :if={@name} type="hidden" name={@name} value="false" />
      <button
        type="button"
        role="switch"
        aria-checked={to_string(@enabled)}
        phx-click={@on_toggle}
        class={[
          "relative w-11 h-6 rounded-full transition-colors duration-200 shrink-0",
          if(@enabled, do: "bg-indigo-500", else: "bg-white/10")
        ]}
        {@rest}
      >
        <span class={[
          "absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform duration-200",
          @enabled && "translate-x-5"
        ]}>
        </span>
      </button>
      <input
        :if={@name}
        type="checkbox"
        id={@id}
        name={@name}
        value="true"
        checked={@enabled}
        class="hidden"
      />
      <span :if={@label} class="text-sm text-slate-300 group-hover:text-slate-100 transition-colors">
        {@label}
      </span>
    </label>
    """
  end

  @doc """
  Search input with magnifier icon and optional clear button.

  ## Examples

      <.search_input value="" placeholder="Search invoices..." on_change="search" />
  """
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search..."
  attr :on_change, :string, default: "search"
  attr :on_clear, :string, default: "clear-search"

  def search_input(assigns) do
    ~H"""
    <div class="relative">
      <span class="hero-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500">
      </span>
      <input
        type="text"
        value={@value}
        placeholder={@placeholder}
        phx-keyup={@on_change}
        phx-debounce="300"
        class="w-full bg-white/[0.04] border border-[var(--nx-border)] rounded-xl pl-10 pr-9 py-2 text-sm text-slate-100 placeholder-slate-600 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/30 transition-all"
      />
      <button
        :if={@value != ""}
        phx-click={@on_clear}
        class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors"
      >
        <span class="hero-x-mark w-4 h-4"></span>
      </button>
    </div>
    """
  end

  @doc """
  Drag and drop file upload zone with progress states.
  Integrates with Phoenix LiveView file uploads.

  ## Examples

      <.file_upload_zone upload={@uploads.statement} accepted_types=".csv, .mt940" max_size="20MB" />
  """
  attr :upload, :any, required: true
  attr :accepted_types, :string, default: ".csv, .mt940, .pdf"
  attr :max_size, :string, default: "20MB"

  def file_upload_zone(assigns) do
    ~H"""
    <div class="relative" phx-drop-target={@upload.ref}>
      <label class={[
        "flex flex-col items-center justify-center w-full py-12 px-6 rounded-2xl border-2 border-dashed transition-all duration-200 cursor-pointer group",
        "border-[var(--nx-border)] hover:border-indigo-500/40 hover:bg-indigo-500/[0.03]"
      ]}>
        <div class="w-14 h-14 rounded-2xl bg-white/[0.04] flex items-center justify-center mb-4 group-hover:bg-indigo-500/10 transition-colors">
          <span class="hero-arrow-up-tray w-7 h-7 text-slate-500 group-hover:text-indigo-400 transition-colors">
          </span>
        </div>
        <p class="text-sm text-slate-300 font-medium">Drag & drop your bank statement here</p>
        <p class="text-xs text-slate-600 mt-1">{@accepted_types} · Max {@max_size}</p>
        <div class="mt-4">
          <span class="text-xs text-indigo-400 font-medium px-4 py-2 rounded-xl border border-indigo-500/30 hover:bg-indigo-500/10 transition-colors">
            Browse Files
          </span>
        </div>
        <.live_file_input upload={@upload} class="hidden" />
      </label>
      <p class="text-[9px] text-center text-slate-600 mt-3">
        🔒 Files are encrypted in transit · scanned on upload
      </p>

      <%!-- Upload entries --%>
      <div
        :for={entry <- @upload.entries}
        class="mt-4 p-4 bg-white/[0.02] rounded-xl border border-[var(--nx-border)]"
      >
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm text-slate-300 font-mono">{entry.client_name}</span>
          <span class="text-xs text-slate-500">{entry.progress}%</span>
        </div>
        <div class="w-full bg-white/[0.06] rounded-full h-1.5">
          <div
            class="bg-indigo-500 h-1.5 rounded-full transition-all duration-300"
            style={"width: #{entry.progress}%"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 4. ACTIONS
  # ══════════════════════════════════════════════════════════════

  @doc """
  Dark-themed button with variants and loading state.

  ## Variants

  - `primary` — Indigo filled button (default)
  - `ghost` — Transparent with subtle hover
  - `danger` — Rose for destructive actions
  - `outline` — Bordered, transparent fill

  ## Examples

      <.nx_button>Save Changes</.nx_button>
      <.nx_button variant="ghost" size="sm">Cancel</.nx_button>
      <.nx_button variant="danger" icon="hero-trash">Delete</.nx_button>
      <.nx_button loading={true}>Processing...</.nx_button>
  """
  attr :variant, :string, default: "primary", values: ~w(primary ghost danger outline)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :icon, :string, default: nil
  attr :loading, :boolean, default: false
  attr :class, :string, default: nil

  attr :rest, :global,
    include:
      ~w(href navigate patch method download name value disabled type phx-click phx-disable-with)

  slot :inner_block, required: true

  def nx_button(assigns) do
    ~H"""
    <button
      class={
        [
          "inline-flex items-center justify-center gap-2 font-medium rounded-xl transition-all duration-200 no-select touch-feedback",
          # Size
          @size == "sm" && "text-xs px-3 py-1.5",
          @size == "md" && "text-sm px-5 py-2.5",
          @size == "lg" && "text-sm px-7 py-3",
          # Variant
          @variant == "primary" &&
            "bg-indigo-500 text-white hover:bg-indigo-400 shadow-lg shadow-indigo-500/20",
          @variant == "ghost" && "text-slate-400 hover:text-slate-200 hover:bg-white/[0.06]",
          @variant == "danger" &&
            "bg-rose-500/15 text-rose-300 hover:bg-rose-500/25 border border-rose-500/20",
          @variant == "outline" &&
            "border border-[var(--nx-border)] text-slate-300 hover:border-[var(--nx-border-hover)] hover:bg-white/[0.04]",
          # Disabled / loading
          (@loading || @rest[:disabled]) && "opacity-50 cursor-not-allowed pointer-events-none",
          @class
        ]
      }
      disabled={@loading || @rest[:disabled]}
      {@rest}
    >
      <.spinner :if={@loading} size="sm" />
      <span :if={@icon && !@loading} class={[@icon, "w-4 h-4"]}></span>
      {render_slot(@inner_block)}
    </button>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 5. FEEDBACK & OVERLAYS
  # ══════════════════════════════════════════════════════════════

  @doc """
  Modal overlay with backdrop, centered content.

  ## Examples

      <.modal id="confirm-trade" show={@show_modal}>
        <h2>Confirm Your Identity</h2>
        <p>This trade is over €100,000</p>
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, :string, default: nil
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "fixed inset-0 z-50 flex items-center justify-center transition-all duration-300",
        if(@show, do: "opacity-100 pointer-events-auto", else: "opacity-0 pointer-events-none")
      ]}
    >
      <%!-- Backdrop --%>
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click={@on_close} />

      <%!-- Content --%>
      <div class={[
        "relative bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-3xl p-8 max-w-lg w-full mx-4 shadow-2xl transition-all duration-300",
        if(@show, do: "scale-100 translate-y-0", else: "scale-95 translate-y-4")
      ]}>
        <button
          :if={@on_close}
          phx-click={@on_close}
          class="absolute top-4 right-4 text-slate-500 hover:text-slate-300 transition-colors"
        >
          <span class="hero-x-mark w-5 h-5"></span>
        </button>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Toast notification for system events.

  ## Examples

      <.toast kind="success" title="Invoice received" message="Invoice #3847 was received successfully." />
      <.toast kind="error" title="Upload failed" message="Could not read your file." />
  """
  attr :id, :string, default: nil
  attr :kind, :string, default: "info", values: ~w(info success warning error)
  attr :title, :string, default: nil
  attr :message, :string, required: true
  attr :on_dismiss, :string, default: nil

  def toast(assigns) do
    assigns = assign_new(assigns, :id, fn -> "toast-#{System.unique_integer([:positive])}" end)

    ~H"""
    <div
      id={@id}
      class={[
        "flex items-start gap-3 p-4 rounded-2xl border shadow-lg max-w-sm",
        "bg-[var(--nx-surface)]",
        @kind == "info" && "border-indigo-500/30",
        @kind == "success" && "border-emerald-500/30",
        @kind == "warning" && "border-amber-500/30",
        @kind == "error" && "border-rose-500/30"
      ]}
    >
      <div class={[
        "w-8 h-8 rounded-xl flex items-center justify-center shrink-0",
        @kind == "info" && "bg-indigo-500/15",
        @kind == "success" && "bg-emerald-500/15",
        @kind == "warning" && "bg-amber-500/15",
        @kind == "error" && "bg-rose-500/15"
      ]}>
        <span :if={@kind == "info"} class="hero-information-circle w-4 h-4 text-indigo-400"></span>
        <span :if={@kind == "success"} class="hero-check-circle w-4 h-4 text-emerald-400"></span>
        <span :if={@kind == "warning"} class="hero-exclamation-triangle w-4 h-4 text-amber-400">
        </span>
        <span :if={@kind == "error"} class="hero-x-circle w-4 h-4 text-rose-400"></span>
      </div>
      <div class="flex-1 min-w-0">
        <p :if={@title} class="text-sm font-medium text-slate-100">{@title}</p>
        <p class={["text-xs text-slate-400", @title && "mt-0.5"]}>{@message}</p>
      </div>
      <button
        :if={@on_dismiss}
        phx-click={@on_dismiss}
        class="text-slate-600 hover:text-slate-400 transition-colors shrink-0"
      >
        <span class="hero-x-mark w-4 h-4"></span>
      </button>
    </div>
    """
  end

  @doc """
  Loading skeleton for placeholder content.

  ## Types: line, card, chart, table

  ## Examples

      <.loading_skeleton type="card" />
      <.loading_skeleton type="line" count={3} />
  """
  attr :type, :string, default: "line", values: ~w(line card chart table)
  attr :count, :integer, default: 1

  def loading_skeleton(assigns) do
    ~H"""
    <%!-- Line --%>
    <div :if={@type == "line"} class="space-y-3 animate-pulse">
      <div
        :for={_ <- 1..@count}
        class="h-3 bg-white/[0.06] rounded-lg"
        style={"width: #{Enum.random(60..100)}%"}
      >
      </div>
    </div>

    <%!-- Card --%>
    <div
      :if={@type == "card"}
      class="animate-pulse bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-[var(--nx-radius-lg)] p-6 space-y-4"
    >
      <div class="h-3 bg-white/[0.06] rounded w-1/3"></div>
      <div class="h-8 bg-white/[0.06] rounded w-2/3"></div>
      <div class="h-3 bg-white/[0.06] rounded w-1/4"></div>
    </div>

    <%!-- Chart --%>
    <div
      :if={@type == "chart"}
      class="animate-pulse bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-[var(--nx-radius-lg)] p-6"
    >
      <div class="h-3 bg-white/[0.06] rounded w-1/4 mb-4"></div>
      <div class="h-48 bg-white/[0.04] rounded-xl flex items-end justify-around px-4 pb-4 gap-2">
        <div
          :for={_ <- 1..8}
          class="bg-white/[0.06] rounded-t"
          style={"width: 10%; height: #{Enum.random(20..90)}%"}
        >
        </div>
      </div>
    </div>

    <%!-- Table --%>
    <div :if={@type == "table"} class="animate-pulse space-y-0">
      <div class="h-10 bg-white/[0.04] border-b border-[var(--nx-border)]"></div>
      <div :for={_ <- 1..5} class="h-14 bg-white/[0.02] border-b border-[var(--nx-border)]"></div>
    </div>
    """
  end

  @doc """
  Spinning loader.

  ## Examples

      <.spinner />
      <.spinner size="lg" />
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)

  def spinner(assigns) do
    ~H"""
    <svg
      class={[
        "animate-spin text-indigo-400",
        @size == "sm" && "w-4 h-4",
        @size == "md" && "w-6 h-6",
        @size == "lg" && "w-8 h-8"
      ]}
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z">
      </path>
    </svg>
    """
  end

  @doc """
  Session status indicator with pulse dot and label.

  ## Examples

      <.session_indicator status="connected" />
      <.session_indicator status="reconnecting" />
      <.session_indicator status="disconnected" />
  """
  attr :status, :string, default: "connected", values: ~w(connected reconnecting disconnected)

  def session_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class={[
        "w-2 h-2 rounded-full",
        @status == "connected" && "bg-emerald-500 animate-pulse",
        @status == "reconnecting" && "bg-amber-500 animate-pulse",
        @status == "disconnected" && "bg-rose-500"
      ]}>
      </span>
      <span class={[
        "text-xs",
        @status == "connected" && "text-emerald-400",
        @status == "reconnecting" && "text-amber-400",
        @status == "disconnected" && "text-rose-400"
      ]}>
        <%= case @status do %>
          <% "connected" -> %>
            Identity Verified
          <% "reconnecting" -> %>
            Reconnecting...
          <% "disconnected" -> %>
            Session expired
        <% end %>
      </span>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 6. SPECIALIZED
  # ══════════════════════════════════════════════════════════════

  @doc """
  Notification dropdown showing recent activity items.

  ## Examples

      <.notification_dropdown notifications={@notifications} />
  """
  attr :notifications, :list, default: []
  attr :show, :boolean, default: false
  attr :on_toggle, :string, default: "toggle-notifications"

  def notification_dropdown(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click={@on_toggle}
        class="relative p-2 text-slate-400 hover:text-slate-200 transition-colors"
      >
        <span class="hero-bell w-5 h-5"></span>
        <span
          :if={length(@notifications) > 0}
          class="absolute -top-0.5 -right-0.5 w-4 h-4 bg-indigo-500 rounded-full text-[9px] font-bold flex items-center justify-center text-white"
        >
          {min(length(@notifications), 9)}
        </span>
      </button>

      <div
        :if={@show}
        class="absolute right-0 top-full mt-2 w-80 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl shadow-2xl overflow-hidden z-50"
      >
        <div class="px-4 py-3 border-b border-[var(--nx-border)]">
          <p class="text-xs font-semibold text-slate-400 uppercase tracking-wider">Recent Activity</p>
        </div>
        <div class="max-h-72 overflow-y-auto scroll-soft">
          <div
            :for={notif <- Enum.take(@notifications, 8)}
            class="px-4 py-3 border-b border-[var(--nx-border)] hover:bg-white/[0.02] transition-colors"
          >
            <p class="text-sm text-slate-300">{notif.message}</p>
            <p class="text-[10px] text-slate-600 mt-0.5">{notif.time}</p>
          </div>
          <div :if={@notifications == []} class="px-4 py-6 text-center">
            <p class="text-xs text-slate-600">No recent activity</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Profile menu dropdown with session info and sign out.

  ## Examples

      <.profile_menu user_name="Elena" session_id="3F8A" />
  """
  attr :user_name, :string, default: "User"
  attr :session_id, :string, default: nil
  attr :show, :boolean, default: false
  attr :on_toggle, :string, default: "toggle-profile"
  attr :on_sign_out, :string, default: "sign-out"

  def profile_menu(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click={@on_toggle}
        class="w-8 h-8 rounded-full bg-indigo-500/15 flex items-center justify-center text-indigo-300 text-sm font-bold hover:bg-indigo-500/25 transition-colors"
      >
        {String.first(@user_name)}
      </button>

      <div
        :if={@show}
        class="absolute right-0 top-full mt-2 w-56 bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-2xl shadow-2xl overflow-hidden z-50"
      >
        <div class="px-4 py-3 border-b border-[var(--nx-border)]">
          <p class="text-sm font-medium text-slate-200">{@user_name}</p>
          <p :if={@session_id} class="text-[10px] text-slate-600 font-mono mt-0.5">
            Session: {@session_id}...
          </p>
        </div>
        <div class="py-1">
          <button
            phx-click={@on_sign_out}
            class="w-full text-left px-4 py-2.5 text-sm text-rose-400 hover:bg-rose-500/10 transition-colors flex items-center gap-2"
          >
            <span class="hero-arrow-right-on-rectangle w-4 h-4"></span> Sign out
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # 7. COMMAND PALETTE
  # ══════════════════════════════════════════════════════════════

  @doc """
  Global Command Menu triggered by Cmd+K.
  """
  def command_palette(assigns) do
    ~H"""
    <div
      id="command-palette-backdrop"
      class="hidden fixed inset-0 z-50 bg-[#0B0E14]/80 backdrop-blur-sm transition-opacity opacity-0 flex items-start justify-center pt-[10vh]"
    >
      <div
        id="command-palette-modal"
        class="relative w-full max-w-2xl bg-[var(--nx-surface)] border border-[var(--nx-border)] rounded-[var(--nx-radius-lg)] shadow-2xl shadow-black/80 overflow-hidden scale-95 transition-all opacity-0"
      >
        <%!-- Header (Input) --%>
        <div class="px-4 py-4 border-b border-[var(--nx-border)] flex items-center gap-3">
          <span class="hero-magnifying-glass w-5 h-5 text-indigo-400"></span>
          <input
            id="command-palette-input"
            type="text"
            placeholder="Search transactions, jump to invoice..."
            autocomplete="off"
            class="flex-1 bg-transparent border-none text-lg text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-0"
          />
          <span class="text-[10px] text-slate-500 font-mono border border-slate-700 rounded px-1.5 py-0.5 bg-slate-800 shadow-sm shrink-0">
            ESC
          </span>
        </div>

        <%!-- Body (Results) --%>
        <div class="max-h-[60vh] overflow-y-auto p-2" id="cmd-pal-results-container">
          <%!-- Initial State --%>
          <div id="cmd-pal-empty" class="py-12 flex flex-col items-center justify-center text-center">
            <span class="hero-magnifying-glass w-8 h-8 text-slate-600 mb-3"></span>
            <p class="text-sm font-medium text-slate-300">Looking for something specific?</p>
            <p class="text-xs text-slate-500 mt-1 max-w-xs">
              Search for invoice IDs, company names, or type a command like "Settings".
            </p>
          </div>

          <%!-- Example Section: Suggestions (Hidden by default, can be toggled via JS) --%>
          <div class="mb-4 hidden" id="cmd-pal-results">
            <h3 class="px-3 py-2 text-[10px] font-bold text-slate-500 uppercase tracking-[0.15em]">
              Recent Activity
            </h3>
            <div class="space-y-0.5">
              <a
                href="#"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/[0.04] text-sm text-slate-300 transition-colors group"
              >
                <span class="hero-document-text w-4 h-4 text-slate-500 group-hover:text-indigo-400 transition-colors">
                </span>
                <span class="flex-1">
                  Invoice <span class="text-white font-medium">#INV-2024-3847</span>
                </span>
                <span class="text-[10px] text-slate-500 font-mono tracking-wider group-hover:text-indigo-300 hidden group-hover:block">
                  JUMP
                </span>
              </a>
              <a
                href="#"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-white/[0.04] text-sm text-slate-300 transition-colors group"
              >
                <span class="hero-banknotes w-4 h-4 text-slate-500 group-hover:text-amber-400 transition-colors">
                </span>
                <span class="flex-1 text-amber-100/80">
                  Pending Settlement <span class="text-white font-medium">#BNK-9924</span>
                </span>
                <span class="text-[10px] text-slate-500 font-mono tracking-wider group-hover:text-amber-300 hidden group-hover:block">
                  REVIEW
                </span>
              </a>
            </div>
          </div>
        </div>

        <%!-- Footer --%>
        <div class="px-4 py-3 border-t border-[var(--nx-border)] bg-slate-800/20 flex items-center justify-between text-[10px] text-slate-500 font-medium">
          <div class="flex items-center gap-4">
            <span class="flex items-center gap-1">
              <kbd class="font-mono bg-slate-800 border border-slate-700 rounded px-1">↑↓</kbd>
              to navigate
            </span>
            <span class="flex items-center gap-1">
              <kbd class="font-mono bg-slate-800 border border-slate-700 rounded px-1">↵</kbd>
              to select
            </span>
          </div>
          <span class="flex items-center gap-1">
            Powered by
            <strong class="text-slate-400 tracking-wider uppercase">Nexus Intelligence</strong>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════
  # INTERNAL HELPERS
  # ══════════════════════════════════════════════════════════════

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(NexusWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(NexusWeb.Gettext, "errors", msg, opts)
    end
  end
end
