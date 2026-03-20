defmodule NexusWeb.Treasury.VaultLive do
  @moduledoc """
  Main dashboard for managing physical bank accounts (Vaults).
  """
  use NexusWeb, :live_view
  import NexusWeb.Treasury.VaultComponents
  alias Nexus.Treasury.Queries.{VaultQuery, TransferQuery}
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
    change_percent = Enum.random(1..50) / 1000 * if Enum.random([true, false]), do: 1, else: -1

    new_amount =
      Decimal.add(
        current_balance,
        Decimal.mult(current_balance, Decimal.from_float(change_percent))
      )

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
  def handle_event("trigger_rebalance", _, socket) do
    # Simulate an autonomous rebalance from USD to EUR
    org_id = socket.assigns.org_id

    # We create a ForecastGenerated event directly or just dispatch RequestTransfer
    # For a demo, we'll dispatch RequestTransfer with user_id: "system-rebalance"
    case VaultQuery.find_vault_for_currency(org_id, "USD") do
      nil ->
        {:noreply, put_flash(socket, :error, "No USD vault found for rebalance source.")}

      usd_vault ->
        eur_vault = VaultQuery.find_vault_for_currency(org_id, "EUR")
        transfer_id = "rebalance-#{org_id}-#{Nexus.Schema.generate_uuidv7()}"
        amount = Decimal.new("125000.00")

        cmd = %Nexus.Treasury.Commands.RequestTransfer{
          transfer_id: transfer_id,
          org_id: org_id,
          user_id: "00000000-0000-0000-0000-000000000000",
          from_currency: "USD",
          to_currency: "EUR",
          amount: amount,
          recipient_data: %{
            type: "vault",
            vault_id: eur_vault.id,
            from_vault_id: usd_vault.id
          },
          requested_at: Nexus.Schema.utc_now()
        }

        case Nexus.App.dispatch(cmd) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Autonomous rebalancing simulation initiated.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Failed to initiate rebalance.")}
        end
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
    rebalance_activities = TransferQuery.list_rebalance_activity(org_id)

    socket
    |> assign(:vaults, vaults)
    |> assign(:stats, stats)
    |> assign(:rebalance_activities, rebalance_activities)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <.page_header title="Vault Center" subtitle="Real-time Liquidity Management">
        <:actions>
          <.nx_button
            :if={can?(@current_user, :trade, :treasury_ops)}
            phx-click="trigger_rebalance"
            variant="outline"
            class="px-6 py-2.5 rounded-xl border border-white/10 bg-white/5 hover:bg-white/10 transition-all mr-3"
          >
            <span class="hero-bolt w-4 h-4 mr-2 text-amber-400"></span> Simulate Rebalance
          </.nx_button>
          <.nx_button
            :if={can?(@current_user, :create, :treasury_ops)}
            phx-click="show_registration"
            variant="primary"
            class="px-6 py-2.5 rounded-xl shadow-lg shadow-indigo-600/20 group"
          >
            <span class="hero-plus w-4 h-4 mr-2 group-hover:rotate-90 transition-transform"></span>
            Register Vault
          </.nx_button>
        </:actions>
      </.page_header>

      <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <%!-- Stats Overview --%>
        <.liquidity_scorecard :if={@vaults != []} stats={@stats} />

        <%!-- Empty State or Vault Grid --%>
        <%= if @vaults == [] do %>
          <div class="py-24 flex flex-col items-center justify-center border-2 border-dashed border-white/5 rounded-[2rem] bg-white/[0.02]">
            <div class="w-20 h-20 rounded-3xl bg-indigo-500/10 flex items-center justify-center mb-8 border border-indigo-500/20">
              <span class="hero-building-library w-10 h-10 text-indigo-400"></span>
            </div>
            <h3 class="text-2xl font-black text-white tracking-tight mb-2">No Vaults Registered</h3>
            <p class="text-slate-500 text-center max-w-sm mb-10 leading-relaxed">
              Connect your institutional bank accounts to enable real-time liquidity monitoring and automated settlements.
            </p>
            <.nx_button
              :if={can?(@current_user, :create, :treasury_ops)}
              phx-click="show_registration"
              variant="primary"
              class="px-10 py-4 rounded-2xl shadow-2xl shadow-indigo-600/30 font-bold group"
            >
              Initiate Onboarding
              <span class="hero-chevron-right w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform">
              </span>
            </.nx_button>
          </div>
        <% else %>
          <div class="grid grid-cols-1 lg:grid-cols-2 2xl:grid-cols-3 gap-6">
            <%= for vault <- @vaults do %>
              <.vault_card vault={vault} />
            <% end %>
          </div>
        <% end %>

        <%!-- Recent Rebalancing Activity (Placeholder for Rebalance Events) --%>
        <.dark_card title="Autonomous Rebalancing Activity" class="mt-8">
          <div :if={@rebalance_activities == []} class="p-12 text-center">
            <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-slate-800/50 mb-4">
              <span class="hero-arrows-right-left w-6 h-6 text-slate-600"></span>
            </div>
            <h4 class="text-sm font-bold text-slate-300">No active movements</h4>
            <p class="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
              The AI Sentinel is monitoring your liquidity positions. Autonomous rebalancing will appear here when triggered.
            </p>
          </div>

          <div :if={@rebalance_activities != []} class="overflow-hidden">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-white/5">
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">
                    Timestamp
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">
                    Movement
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">
                    Amount
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-slate-500">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <tr
                  :for={activity <- @rebalance_activities}
                  class="group hover:bg-white/[0.02] transition-colors"
                >
                  <td class="px-6 py-4">
                    <div class="text-sm font-medium text-slate-300">
                      {Calendar.strftime(activity.created_at, "%H:%M:%S")}
                    </div>
                    <div class="text-[10px] text-slate-500">
                      {Calendar.strftime(activity.created_at, "%d %b %Y")}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/20">
                        <.icon name="hero-arrows-right-left" class="w-4 h-4 text-indigo-400" />
                      </div>
                      <div>
                        <div class="text-sm font-bold text-white">
                          {activity.from_currency} → {activity.to_currency}
                        </div>
                        <div class="text-[10px] text-slate-500">Autonomous Settlement</div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <div class="text-sm font-black text-white">
                      {format_currency(activity.amount, currency: activity.from_currency)}
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <.rebalance_status status={activity.status} />
                  </td>
                </tr>
              </tbody>
            </table>
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

  defp rebalance_status(assigns) do
    {label, color} =
      case assigns.status do
        "executed" -> {"Success", "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"}
        "pending" -> {"Pending", "bg-amber-500/10 text-amber-400 border-amber-500/20"}
        "authorized" -> {"Authorized", "bg-indigo-500/10 text-indigo-400 border-indigo-500/20"}
        _ -> {"Failed", "bg-rose-500/10 text-rose-400 border-rose-500/20"}
      end

    assigns = assign(assigns, label: label, color: color)

    ~H"""
    <span class={[
      "px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider border",
      @color
    ]}>
      {@label}
    </span>
    """
  end
end
