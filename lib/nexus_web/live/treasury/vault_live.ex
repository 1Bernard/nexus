defmodule NexusWeb.Treasury.VaultLive do
  @moduledoc """
  Main dashboard for managing physical bank accounts (Vaults).
  """
  use NexusWeb, :live_view
  import NexusWeb.Treasury.VaultComponents
  alias Nexus.Treasury.Queries.VaultQuery
  alias NexusWeb.Treasury.Components.VaultRegistrationModal

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to vault events for real-time balance updates
      Phoenix.PubSub.subscribe(Nexus.PubSub, "vaults")
    end

    org_id = socket.assigns.current_user.org_id

    {:ok,
     socket
    |> assign(:page_title, "Vault Center")
    |> assign(:page_subtitle, "Real-time Liquidity Management")
    |> assign(:current_path, "/vaults")
    |> assign(:org_id, org_id)
    |> assign(:show_registration, false)
    |> load_data()}
  end

  @impl true
  def handle_event("show_registration", _, socket) do
    {:noreply, assign(socket, :show_registration, true)}
  end

  @impl true
  def handle_event("sync_vault", %{"id" => id}, socket) do
    vault = Enum.find(socket.assigns.vaults, &(&1.id == id))

    # For demo purposes, we simulate a sync with a slightly randomized balance update (+/- 1-5%)
    # In production, this would call the actual bank provider API.
    current_balance = vault.balance || Decimal.new(0)
    change_percent = (Enum.random(1..50) / 1000) * (if Enum.random([true, false]), do: 1, else: -1)
    new_amount = Decimal.add(current_balance, Decimal.mult(current_balance, Decimal.from_float(change_percent)))

    case Nexus.Treasury.sync_vault_balance(%{
           vault_id: id,
           org_id: socket.assigns.org_id,
           amount: new_amount,
           currency: vault.currency
         }) do
      :ok ->
        {:noreply, put_flash(socket, :info, "Vault synchronization requested.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to request sync.")}
    end
  end

  @impl true
  def handle_info({:vault_registration_submitted, params}, socket) do
    params = Map.put(params, "org_id", socket.assigns.org_id)

    case Nexus.Treasury.register_vault(params) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Vault registration initiated successfully.")
         |> assign(:show_registration, false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to register vault.")}
    end
  end

  @impl true
  def handle_info(:close_registration_modal, socket) do
    {:noreply, assign(socket, :show_registration, false)}
  end

  @impl true
  def handle_info({:vault_event, _event}, socket) do
    # When any vault event occurs, refresh the UI data
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp load_data(socket) do
    org_id = socket.assigns.org_id
    vaults = VaultQuery.list_all(org_id)
    stats = VaultQuery.get_stats(org_id)

    socket
    |> assign(:vaults, vaults)
    |> assign(:stats, stats)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <.page_header title="Vault Center" subtitle="Real-time Liquidity Management" />

      <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <%!-- Stats Overview --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <.stat_card
            label="Total USD Liquidity"
            value={format_currency(@stats.total_usd, currency: "USD")}
            icon="hero-banknotes"
          />
          <.stat_card
            label="Total EUR Liquidity"
            value={format_currency(@stats.total_eur, currency: "EUR")}
            icon="hero-globe-europe-africa"
          />
          <.stat_card
            label="Connected Vaults"
            value={to_string(@stats.count)}
            icon="hero-building-library"
          />
        </div>

        <%!-- Vault Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 2xl:grid-cols-3 gap-6">
          <%= for vault <- @vaults do %>
            <.vault_card vault={vault} />
          <% end %>

          <%!-- Create New Button (Elite Style) --%>
          <button
            phx-click="show_registration"
            class="relative group h-[300px] border-2 border-dashed border-slate-800 rounded-2xl flex flex-col items-center justify-center gap-3 hover:border-indigo-500/40 hover:bg-indigo-500/5 transition-all duration-300"
          >
            <div class="w-12 h-12 rounded-full bg-slate-800 flex items-center justify-center group-hover:scale-110 transition-transform">
              <.icon name="hero-plus" class="w-6 h-6 text-slate-500 group-hover:text-indigo-400" />
            </div>
            <span class="text-xs font-bold uppercase tracking-widest text-slate-500 group-hover:text-indigo-300 transition-colors">
              Register New Vault
            </span>
            <div class="absolute inset-x-0 bottom-4 px-8 text-center opacity-0 group-hover:opacity-100 transition-opacity">
              <p class="text-[10px] text-slate-600 leading-relaxed font-medium">
                Add secure bank connectivity for institutional settlements.
              </p>
            </div>
          </button>
        </div>

        <%!-- Recent Rebalancing Activity (Placeholder for Rebalance Events) --%>
        <.dark_card title="Autonomous Rebalancing Activity" class="mt-8">
          <div class="p-12 text-center">
            <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-slate-800/50 mb-4">
              <span class="hero-arrows-right-left w-6 h-6 text-slate-600"></span>
            </div>
            <h4 class="text-sm font-bold text-slate-300">No active movements</h4>
            <p class="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
              The AI Sentinel is monitoring your liquidity positions. Autonomous rebalancing will appear here when triggered.
            </p>
          </div>
        </.dark_card>
      </div>

      <.live_component
        module={VaultRegistrationModal}
        id="register-vault-modal"
        show={@show_registration}
      />
    </.page_container>
    """
  end
end
