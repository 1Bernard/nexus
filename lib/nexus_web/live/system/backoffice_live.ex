defmodule NexusWeb.System.BackofficeLive do
  @moduledoc """
  LiveView for the system backoffice — tenant provisioning, suspension, module toggles,
  and God-Mode impersonation controls.
  """
  use NexusWeb, :live_view

  import NexusWeb.NexusComponents
  import Ecto.Query
  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Organization.Commands.SuspendTenant
  alias Nexus.Organization.Commands.ToggleTenantModule

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Nexus.PubSub, "tenants")

    tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)
    health = Nexus.System.Health.get_summary()

    audit_logs =
      Nexus.Repo.all(
        from l in Nexus.Reporting.Projections.AuditLog,
          order_by: [desc: l.recorded_at],
          limit: 10
      )

    socket =
      socket
      |> assign(:page_title, "PLATFORM BACKOFFICE")
      |> assign(:page_subtitle, "System Administrator Zone")
      |> assign(:current_path, "/backoffice")
      # Passed down to app_shell via layout
      |> assign(:is_backoffice, true)
      |> assign(:form, to_form(%{"name" => "", "admin_email" => ""}))
      |> assign(:show_provision_modal, false)
      |> assign(:selected_tenant_id, nil)
      |> assign(:tenants, tenants)
      |> assign(:health, health)
      |> assign(:audit_logs, audit_logs)
      |> assign(:params, %{})
      |> assign(:active_tab, "tenants")

    {:ok, socket}
  end

  def handle_info({:tenant_updated, _tenant}, socket) do
    tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)
    health = Nexus.System.Health.get_summary()

    audit_logs =
      Nexus.Repo.all(
        from l in Nexus.Reporting.Projections.AuditLog,
          order_by: [desc: l.recorded_at],
          limit: 10
      )

    {:noreply, assign(socket, tenants: tenants, health: health, audit_logs: audit_logs)}
  end

  def render(assigns) do
    ~H"""
    <.page_container class="px-4 sm:px-6 lg:px-8 animate-fade-in pb-12">
      <.page_header
        title="PLATFORM BACKOFFICE"
        subtitle="System Administrator Zone"
        is_backoffice={true}
      />

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 my-8">
        <.stat_card
          label="Active Tenants"
          value={@health.active_tenants |> to_string()}
          icon="hero-building-office"
        />
        <.stat_card label="Event Store Lag" value={"#{@health.event_store_lag}ms"} icon="hero-clock" />
        <.stat_card label="System Health" value={@health.system_health} icon="hero-heart" />
      </div>
      
    <!-- Navigation Tabs -->
      <div class="flex items-center gap-6 border-b border-white/10 mb-6 w-full mt-4">
        <.tab_button
          active={@active_tab == "tenants"}
          click="set_tab"
          tab="tenants"
          label="Tenant Directory"
          count={length(@tenants)}
        />
        <.tab_button
          active={@active_tab == "activity"}
          click="set_tab"
          tab="activity"
          label="Recent Activity"
        />
      </div>

      <%= if @active_tab == "tenants" do %>
        <.data_grid
          id="tenants-grid"
          title="Tenant Directory"
          subtitle="Manage platform partitions and organizational contexts"
          rows={@tenants}
          total={Enum.count(@tenants)}
        >
          <:primary_actions>
            <button
              phx-click="toggle_provision_modal"
              class="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white text-[11px] font-bold uppercase tracking-wider rounded-lg transition-all shadow-[0_0_15px_rgba(225,29,72,0.3)] flex items-center gap-2"
            >
              <span class="hero-plus w-4 h-4"></span> Provision Tenant
            </button>
          </:primary_actions>

          <:col :let={tenant} label="Tenant Name">
            <span class="font-bold text-slate-200">{tenant.name}</span>
          </:col>
          <:col :let={tenant} label="Org ID" class="font-mono text-xs text-slate-500">
            {String.slice(tenant.org_id, 0, 8)}...
          </:col>
          <:col :let={tenant} label="Status">
            <span class="px-2 py-1 text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded">
              {tenant.status}
            </span>
          </:col>
          <:col :let={tenant} label="Admin Email" class="text-slate-400 text-xs">
            {tenant.initial_admin_email || "N/A"}
          </:col>
          <:action :let={tenant}>
            <button
              phx-click="manage_tenant"
              phx-value-id={tenant.org_id}
              class="w-8 h-8 rounded-lg bg-slate-800/50 hover:bg-rose-500/20 text-slate-400 hover:text-rose-400 border border-slate-700/50 hover:border-rose-500/30 flex items-center justify-center transition-all"
              title="Manage Tenant"
            >
              <span class="hero-cog-8-tooth w-4 h-4"></span>
            </button>
          </:action>
        </.data_grid>
      <% end %>

      <%= if @active_tab == "activity" do %>
        <.data_grid
          id="audit-grid"
          title="Recent Admin Activity"
          subtitle="Immutable log of system administrative actions"
          rows={@audit_logs}
          total={Enum.count(@audit_logs)}
        >
          <:col :let={log} label="Action">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-slate-800/50 flex items-center justify-center text-slate-400">
                <span class={event_icon(log.event_type) <> " w-4 h-4"}></span>
              </div>
              <span class="text-xs font-medium text-slate-200">
                {render_event_title(log)}
              </span>
            </div>
          </:col>
          <:col :let={log} label="Actor" class="text-xs text-slate-400">
            {log.actor_email}
          </:col>
          <:col :let={log} label="Target Tenant">
            <%= if log.tenant_name do %>
              <span class="px-2 py-0.5 text-[9px] font-bold uppercase tracking-widest bg-slate-800 text-slate-400 rounded">
                {log.tenant_name}
              </span>
            <% else %>
              <span class="text-xs text-slate-600 italic">System Wide</span>
            <% end %>
          </:col>
          <:col :let={log} label="Timestamp" class="text-[10px] text-slate-500 font-mono">
            {Calendar.strftime(log.recorded_at, "%b %d, %H:%M:%S UTC")}
          </:col>
        </.data_grid>
      <% end %>

      <.modal id="provision-modal" show={@show_provision_modal} on_close="toggle_provision_modal">
        <div class="flex items-center gap-3 mb-6">
          <div class="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
            <span class="hero-building-office-2 w-6 h-6"></span>
          </div>
          <div>
            <h3 class="text-xl font-bold text-slate-100 italic font-serif">New Tenant</h3>
            <p class="text-xs text-slate-500">Create a dedicated partition for a new organization.</p>
          </div>
        </div>

        <.form for={@form} phx-submit="provision_tenant" class="space-y-6">
          <.nx_input
            name="name"
            label="Organization Name"
            placeholder="e.g. Stark Industries"
            required
            field={@form[:name]}
          />

          <.nx_input
            name="admin_email"
            type="email"
            label="Initial Admin Email"
            placeholder="admin@organization.com"
            required
            field={@form[:admin_email]}
          />

          <div class="flex justify-end gap-3 pt-6 border-t border-white/5">
            <.nx_button type="button" variant="ghost" phx-click="toggle_provision_modal">
              Cancel
            </.nx_button>
            <button
              type="submit"
              class="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white text-[11px] font-bold uppercase tracking-wider rounded-lg transition-all shadow-[0_0_15px_rgba(225,29,72,0.3)]"
            >
              Provision
            </button>
          </div>
        </.form>
      </.modal>

      <.slide_over
        :if={@selected_tenant_id}
        id="manage-tenant-slideover"
        show={!is_nil(@selected_tenant_id)}
        on_close="close_manage_modal"
        title="Tenant Configuration"
        subtitle={"God-mode administration for #{Enum.find(@tenants, &(&1.org_id == @selected_tenant_id)).name}"}
      >
        <% tenant = Enum.find(@tenants, &(&1.org_id == @selected_tenant_id)) %>

        <div class="space-y-12">
          <%!-- Section 1: Service Lifecycle --%>
          <section>
            <h3 class="text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
              <span class="hero-cpu-chip w-3 h-3 text-rose-500"></span> Service & Lifecycle Controls
            </h3>

            <div class="grid grid-cols-1 gap-4">
              <div class="p-5 rounded-2xl bg-slate-950/40 border border-slate-800/50 hover:border-indigo-500/30 transition-all group">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded-xl flex items-center justify-center bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                      <span class="hero-users w-5 h-5"></span>
                    </div>
                    <div>
                      <p class="text-sm font-bold text-slate-100">User Impersonation</p>
                      <p class="text-[10px] text-slate-500">
                        Access support session as first tenant user
                      </p>
                    </div>
                  </div>
                  <.nx_button variant="outline" size="sm" type="button" phx-click="impersonate_tenant">
                    Access Session
                  </.nx_button>
                </div>
              </div>

              <div class="p-5 rounded-2xl bg-rose-500/5 border border-rose-500/20 hover:bg-rose-500/10 transition-all group">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded-xl flex items-center justify-center bg-rose-950 text-rose-500 border border-rose-900 shadow-[0_0_10px_rgba(225,29,72,0.2)]">
                      <span class="hero-no-symbol w-5 h-5"></span>
                    </div>
                    <div>
                      <p class="text-sm font-bold text-rose-500">Suspend Tenant</p>
                      <p class="text-[10px] text-rose-400/60">
                        Immediately revoke all access (Destructive)
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="suspend_tenant"
                    data-confirm="Immediately invalidate all active sessions for this tenant?"
                    class="px-3 py-1.5 bg-rose-950 hover:bg-rose-900 text-rose-400 text-xs font-bold rounded-lg border border-rose-800 transition-colors"
                  >
                    Suspend
                  </button>
                </div>
              </div>
            </div>
          </section>

          <%!-- Section 2: Feature Entitlements --%>
          <section>
            <h3 class="text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] mb-6 flex items-center gap-2">
              <span class="hero-key w-3 h-3 text-emerald-500"></span> Feature Entitlements
            </h3>

            <div class="space-y-8">
              <div
                :for={{category, features} <- Nexus.Organization.Entitlement.grouped_by_category()}
                class="space-y-4"
              >
                <h4 class="text-[9px] font-black text-slate-600 uppercase tracking-widest flex items-center gap-2">
                  <span class="w-1 h-1 rounded-full bg-slate-700"></span>
                  {category}
                </h4>

                <div class="grid grid-cols-1 gap-2">
                  <div
                    :for={feature <- features}
                    class="flex items-center justify-between p-4 rounded-xl bg-slate-900/40 border border-white/5 hover:border-white/10 transition-all"
                  >
                    <div class="flex-1">
                      <div class="flex items-center gap-2 mb-0.5">
                        <p class="text-xs font-bold text-slate-300">{feature.name}</p>
                        <span
                          :if={feature.tier == :premium}
                          class="px-1.5 py-0.5 text-[8px] font-black uppercase bg-rose-500/10 text-rose-400 border border-rose-500/20 rounded-full"
                        >
                          Premium
                        </span>
                      </div>
                      <p class="text-[10px] text-slate-500">{feature.description}</p>
                    </div>

                    <% is_enabled = feature.id in (tenant.modules_enabled || []) %>
                    <button
                      type="button"
                      phx-click="toggle_module"
                      phx-value-module={feature.id}
                      phx-value-enabled={if is_enabled, do: "false", else: "true"}
                      class={[
                        "relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200",
                        if(is_enabled,
                          do: "bg-emerald-500/80 shadow-[0_0_8px_rgba(16,185,129,0.3)]",
                          else: "bg-slate-800"
                        )
                      ]}
                    >
                      <span class={[
                        "pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white transition duration-200",
                        if(is_enabled, do: "translate-x-4", else: "translate-x-0")
                      ]}>
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>

        <:footer>
          <div class="flex justify-end">
            <.nx_button variant="ghost" type="button" phx-click="close_manage_modal">Done</.nx_button>
          </div>
        </:footer>
      </.slide_over>
    </.page_container>
    """
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("toggle_provision_modal", _, socket) do
    {:noreply, assign(socket, show_provision_modal: !socket.assigns.show_provision_modal)}
  end

  def handle_event("manage_tenant", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_tenant_id: id)}
  end

  def handle_event("close_manage_modal", _, socket) do
    {:noreply, assign(socket, selected_tenant_id: nil)}
  end

  def handle_event("suspend_tenant", _, socket) do
    tenant_id = socket.assigns.selected_tenant_id
    admin_email = socket.assigns.current_user.email || "system_admin"

    cmd = %SuspendTenant{
      org_id: tenant_id,
      suspended_by: admin_email,
      reason: "Administrative action via Backoffice",
      suspended_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(cmd) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant successfully suspended.")
         |> assign(:selected_tenant_id, nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend instance: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_module", %{"module" => mod_name, "enabled" => enabled_str}, socket) do
    tenant_id = socket.assigns.selected_tenant_id
    admin_email = socket.assigns.current_user.email || "system_admin"
    enabled = enabled_str == "true"

    cmd = %ToggleTenantModule{
      org_id: tenant_id,
      module_name: mod_name,
      enabled: enabled,
      toggled_by: admin_email,
      toggled_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(cmd) do
      :ok ->
        action = if enabled, do: "enabled", else: "disabled"
        {:noreply, put_flash(socket, :info, "Module '#{mod_name}' #{action}.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle module: #{inspect(reason)}")}
    end
  end

  def handle_event("impersonate_tenant", _, socket) do
    tenant_id = socket.assigns.selected_tenant_id

    # Very basic query to find the first user in the tenant to impersonate
    target_user =
      Nexus.Repo.one(
        from u in Nexus.Identity.Projections.User, where: u.org_id == ^tenant_id, limit: 1
      )

    if target_user do
      {:noreply, push_navigate(socket, to: ~p"/backoffice/impersonate/#{target_user.id}")}
    else
      {:noreply, put_flash(socket, :error, "No users found in this tenant to impersonate.")}
    end
  end

  def handle_event("provision_tenant", %{"name" => name, "admin_email" => email}, socket) do
    org_id = Ecto.UUID.generate()

    cmd = %ProvisionTenant{
      org_id: org_id,
      name: name,
      initial_admin_email: email,
      provisioned_by: socket.assigns.current_user.email || "system_admin",
      provisioned_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(cmd) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant #{name} provisioned successfully.")
         |> assign(:show_provision_modal, false)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Provisioning failed: #{inspect(reason)}")}
    end
  end

  # --- UI Helpers ---

  defp event_icon("tenant_provisioned"), do: "hero-building-office-2"
  defp event_icon("tenant_suspended"), do: "hero-no-symbol"
  defp event_icon("tenant_module_toggled"), do: "hero-key"
  defp event_icon(_), do: "hero-bolt"

  defp render_event_title(%{event_type: "tenant_provisioned", tenant_name: name}) do
    "Provisioned new tenant: #{name}"
  end

  defp render_event_title(%{event_type: "tenant_suspended", tenant_name: name}) do
    "Suspended tenant: #{name}"
  end

  defp render_event_title(%{
         event_type: "tenant_module_toggled",
         details: %{"module_name" => mod, "enabled" => true}
       }) do
    "Enabled feature: #{mod}"
  end

  defp render_event_title(%{
         event_type: "tenant_module_toggled",
         details: %{"module_name" => mod}
       }) do
    "Disabled feature: #{mod}"
  end

  defp render_event_title(log),
    do: log.event_type |> String.replace("_", " ") |> String.capitalize()

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
