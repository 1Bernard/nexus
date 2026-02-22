defmodule NexusWeb.BackofficeLive do
  use NexusWeb, :live_view

  import NexusWeb.NexusComponents
  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Repo
  alias Nexus.Organization.Projections.Tenant

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Nexus.PubSub, "tenants")

    tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)

    socket =
      socket
      |> assign(:page_title, "Platform Backoffice")
      |> assign(:form, to_form(%{"name" => "", "admin_email" => ""}))
      |> assign(:show_provision_modal, false)
      |> assign(:tenants, tenants)

    {:ok, socket}
  end

  def handle_info({:tenant_updated, _tenant}, socket) do
    tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)
    {:noreply, assign(socket, tenants: tenants)}
  end

  def render(assigns) do
    ~H"""
    <.dark_page>
      <.dark_card title="Platform Backoffice">
        <p class="text-slate-400 mb-6 font-mono text-sm uppercase tracking-wider">
          System Administrator Zone
        </p>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <!-- KPI Cards -->
          <div class="col-span-1 bg-slate-900 border border-slate-800 rounded-xl p-5 shadow-inner">
            <h3 class="text-slate-500 font-mono text-xs uppercase tracking-wider mb-2">
              Active Tenants
            </h3>
            <p class="text-3xl font-light text-cyan-400">12</p>
          </div>
          <div class="col-span-1 bg-slate-900 border border-slate-800 rounded-xl p-5 shadow-inner">
            <h3 class="text-slate-500 font-mono text-xs uppercase tracking-wider mb-2">
              Event Store Lag
            </h3>
            <p class="text-3xl font-light text-emerald-400">0ms</p>
          </div>
          <div class="col-span-1 bg-slate-900 border border-slate-800 rounded-xl p-5 shadow-inner">
            <h3 class="text-slate-500 font-mono text-xs uppercase tracking-wider mb-2">
              System Health
            </h3>
            <p class="text-3xl font-light text-emerald-400">Nominal</p>
          </div>
        </div>

        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-light text-slate-200">Tenant Directory</h2>
          <button
            phx-click="toggle_provision_modal"
            class="px-4 py-2 bg-gradient-to-r from-cyan-600 to-emerald-600 hover:from-cyan-500 hover:to-emerald-500 text-white font-mono text-sm tracking-wider rounded border border-cyan-400/30 transition-all duration-300 shadow-[0_0_15px_rgba(6,182,212,0.3)] hover:shadow-[0_0_25px_rgba(6,182,212,0.5)]"
          >
            + Provision Tenant
          </button>
        </div>
        
    <!-- Tenant DataGrid Placeholder -->
        <div class="w-full bg-slate-900 border border-slate-800 rounded-xl overflow-hidden mt-4">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="border-b border-slate-800/80 bg-slate-800/50">
                <th class="py-3 px-4 font-mono text-xs uppercase tracking-wider text-slate-500">
                  Tenant Name
                </th>
                <th class="py-3 px-4 font-mono text-xs uppercase tracking-wider text-slate-500">
                  Org ID
                </th>
                <th class="py-3 px-4 font-mono text-xs uppercase tracking-wider text-slate-500">
                  Status
                </th>
                <th class="py-3 px-4 font-mono text-xs uppercase tracking-wider text-slate-500">
                  Admin Email
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if Enum.empty?(@tenants) do %>
                <tr>
                  <td colspan="4" class="py-8 text-center text-slate-500 font-mono text-sm">
                    No tenants found. Provision one to get started.
                  </td>
                </tr>
              <% else %>
                <%= for tenant <- @tenants do %>
                  <tr class="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors">
                    <td class="py-3 px-4 text-slate-300">{tenant.name}</td>
                    <td class="py-3 px-4 text-slate-500 font-mono text-xs">
                      {String.slice(tenant.org_id, 0, 8)}...
                    </td>
                    <td class="py-3 px-4">
                      <span class="px-2 py-0.5 rounded text-xs font-mono bg-emerald-900/30 text-emerald-400 border border-emerald-800">
                        {tenant.status}
                      </span>
                    </td>
                    <td class="py-3 px-4 text-slate-400">{tenant.initial_admin_email || "N/A"}</td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </.dark_card>
    </.dark_page>

    <!-- Provisioning Modal -->
    <%= if @show_provision_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
        <div class="bg-slate-900 border border-slate-700 p-8 rounded-xl max-w-md w-full shadow-[0_0_50px_rgba(0,0,0,0.5)] transform transition-all">
          <h2 class="text-2xl font-light text-slate-100 mb-2">New Tenant</h2>
          <p class="text-slate-400 text-sm mb-6">
            Create a dedicated partition for a new organization.
          </p>

          <.form for={@form} phx-submit="provision_tenant" class="space-y-4">
            <div>
              <label class="block text-slate-400 text-xs uppercase tracking-wider font-mono mb-2">
                Organization Name
              </label>
              <input
                type="text"
                name="name"
                value={@form[:name].value}
                required
                class="w-full bg-slate-800 border border-slate-700 rounded p-3 text-slate-200 focus:outline-none focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500/50 transition-all placeholder-slate-600"
                placeholder="e.g. Stark Industries"
              />
            </div>

            <div>
              <label class="block text-slate-400 text-xs uppercase tracking-wider font-mono mb-2">
                Initial Admin Email
              </label>
              <input
                type="email"
                name="admin_email"
                value={@form[:admin_email].value}
                required
                class="w-full bg-slate-800 border border-slate-700 rounded p-3 text-slate-200 focus:outline-none focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500/50 transition-all placeholder-slate-600"
                placeholder="admin@organization.com"
              />
            </div>

            <div class="flex justify-end gap-4 mt-8 pt-4 border-t border-slate-800">
              <button
                type="button"
                phx-click="toggle_provision_modal"
                class="px-4 py-2 text-slate-400 hover:text-slate-200 font-mono text-sm tracking-wider transition-colors"
              >
                CANCEL
              </button>
              <button
                type="submit"
                class="px-6 py-2 bg-gradient-to-r from-cyan-600 to-emerald-600 hover:from-cyan-500 hover:to-emerald-500 text-white font-mono text-sm tracking-wider rounded border border-cyan-400/30 transition-all duration-300"
              >
                PROVISION
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("toggle_provision_modal", _, socket) do
    {:noreply, assign(socket, show_provision_modal: !socket.assigns.show_provision_modal)}
  end

  def handle_event("provision_tenant", %{"name" => name, "admin_email" => email}, socket) do
    org_id = Ecto.UUID.generate()

    cmd = %ProvisionTenant{
      org_id: org_id,
      name: name,
      initial_admin_email: email,
      provisioned_by: socket.assigns.current_user.email || "system_admin"
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
end
