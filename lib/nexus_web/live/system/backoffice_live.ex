defmodule NexusWeb.System.BackofficeLive do
  use NexusWeb, :live_view

  import NexusWeb.NexusComponents
  alias Nexus.Organization.Commands.ProvisionTenant

  on_mount {NexusWeb.UserAuth, :mount_current_user}
  on_mount {NexusWeb.UserAuth, :require_system_admin}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Nexus.PubSub, "tenants")

    tenants = Nexus.Repo.all(Nexus.Organization.Projections.Tenant)

    socket =
      socket
      |> assign(:page_title, "Platform Backoffice")
      |> assign(:page_subtitle, "System Administrator Zone")
      |> assign(:current_path, "/backoffice")
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
    <div class="flex flex-col gap-6 w-full pb-12">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <.stat_card
          label="Active Tenants"
          value={Enum.count(@tenants) |> to_string()}
          icon="hero-building-office"
        />
        <.stat_card label="Event Store Lag" value="0ms" icon="hero-clock" />
        <.stat_card label="System Health" value="Nominal" icon="hero-heart" />
      </div>

      <.dark_card title="Tenant Directory">
        <:header_actions>
          <.nx_button phx-click="toggle_provision_modal" size="sm" icon="hero-plus">
            Provision Tenant
          </.nx_button>
        </:header_actions>

        <div class="mt-6">
          <.data_table id="tenants-table" rows={@tenants}>
            <:col :let={tenant} label="Tenant Name">{tenant.name}</:col>
            <:col :let={tenant} label="Org ID" class="font-mono text-xs">
              {String.slice(tenant.org_id, 0, 8)}...
            </:col>
            <:col :let={tenant} label="Status">
              <.badge variant="success" label={tenant.status} />
            </:col>
            <:col :let={tenant} label="Admin Email" class="text-slate-400">
              {tenant.initial_admin_email || "N/A"}
            </:col>
            <:action :let={_tenant}>
              <.nx_button variant="ghost" size="sm">Manage</.nx_button>
            </:action>
          </.data_table>

          <%= if Enum.empty?(@tenants) do %>
            <.empty_state
              icon="hero-building-office-2"
              title="No tenants found"
              message="Provision your first organization to begin partitioning data."
            />
          <% end %>
        </div>
      </.dark_card>

      <.modal id="provision-modal" show={@show_provision_modal} on_close="toggle_provision_modal">
        <h2 class="text-2xl font-bold text-white mb-2">New Tenant</h2>
        <p class="text-slate-400 text-sm mb-8 leading-relaxed">
          Create a dedicated partition for a new organization. This will generate a unique Org ID and set up the initial admin context.
        </p>

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
            <.nx_button type="submit" variant="primary">
              Provision
            </.nx_button>
          </div>
        </.form>
      </.modal>
    </div>
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
