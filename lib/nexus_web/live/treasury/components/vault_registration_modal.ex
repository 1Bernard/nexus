defmodule NexusWeb.Treasury.Components.VaultRegistrationModal do
  @moduledoc """
  Elite 'Register Vault' modal component.
  Matches the high-stakes aesthetic of the TransferModal.
  """
  use NexusWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"currency" => "USD", "provider" => "manual"}),
       currencies: ["USD", "EUR", "GBP", "JPY", "CHF"],
       providers: [{"Manual Entry", "manual"}, {"Paystack Sync", "paystack"}]
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"vault" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :vault))}
  end

  @impl true
  def handle_event("save", %{"vault" => params}, socket) do
    send(self(), {:vault_registration_submitted, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_registration_modal)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.nx_modal
        id={@id <> "-shell"}
        show={@show}
        on_close={JS.push("close", target: @myself)}
        class="max-w-2xl"
      >
        <div class="relative z-10">
          <.modal_header
            title="Register New Vault"
            subtitle="Connect Physical Bank Account • Nexus Treasury"
            icon="hero-building-library"
          />

          <.form
            for={@form}
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-8"
            as={:vault}
          >
            <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Vault Name
                </label>
                <input
                  type="text"
                  name="vault[name]"
                  value={@form[:name].value}
                  placeholder="e.g. JPMorgan Operating"
                  required
                  class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-bold text-white placeholder:text-slate-700 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all hover:border-white/20"
                />
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Bank Name
                </label>
                <input
                  type="text"
                  name="vault[bank_name]"
                  value={@form[:bank_name].value}
                  placeholder="e.g. JPMorgan Chase"
                  required
                  class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-bold text-white placeholder:text-slate-700 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all hover:border-white/20"
                />
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Currency
                </label>
                <div class="relative group">
                  <select
                    name="vault[currency]"
                    class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-bold text-white focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all appearance-none cursor-pointer hover:border-white/20"
                  >
                    <%= for c <- @currencies do %>
                      <option value={c} selected={@form[:currency].value == c}>{c}</option>
                    <% end %>
                  </select>
                  <span class="hero-chevron-down w-4 h-4 text-slate-500 absolute right-5 top-1/2 -translate-y-1/2 pointer-events-none">
                  </span>
                </div>
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Provider
                </label>
                <div class="relative group">
                  <select
                    name="vault[provider]"
                    class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-bold text-white focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all appearance-none cursor-pointer hover:border-white/20"
                  >
                    <%= for {label, value} <- @providers do %>
                      <option value={value} selected={@form[:provider].value == value}>{label}</option>
                    <% end %>
                  </select>
                  <span class="hero-chevron-down w-4 h-4 text-slate-500 absolute right-5 top-1/2 -translate-y-1/2 pointer-events-none">
                  </span>
                </div>
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Account Number
                </label>
                <input
                  type="text"
                  name="vault[account_number]"
                  value={@form[:account_number].value}
                  placeholder="•••• 1234"
                  class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-mono font-bold text-white placeholder:text-slate-700 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all hover:border-white/20"
                />
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  IBAN (Europe Only)
                </label>
                <input
                  type="text"
                  name="vault[iban]"
                  value={@form[:iban].value}
                  placeholder="GB29..."
                  class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-sm font-mono font-bold text-white placeholder:text-slate-700 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all hover:border-white/20"
                />
              </div>
            </div>

            <div class="pt-6 border-t border-white/5 flex gap-4">
              <button
                type="button"
                phx-click="close"
                phx-target={@myself}
                class="flex-1 bg-white/5 hover:bg-white/10 text-slate-300 py-4 rounded-2xl font-bold text-sm transition-all active:scale-[0.98]"
              >
                Dismiss
              </button>
              <button
                type="submit"
                class="flex-1 bg-indigo-600 hover:bg-indigo-500 text-white py-4 rounded-2xl font-bold text-sm shadow-xl shadow-indigo-600/20 transition-all active:scale-[0.98] flex items-center justify-center gap-3 group"
              >
                Initiate Registration
                <span class="hero-arrow-right w-4 h-4 group-hover:translate-x-1 transition-transform">
                </span>
              </button>
            </div>
          </.form>

          <div class="mt-10 flex justify-center gap-8 opacity-40 grayscale pointer-events-none scale-90">
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              <span class="hero-shield-check w-4 h-4"></span> End-to-End Encryption
            </div>
            <div class="flex items-center gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              <span class="hero-building-library w-4 h-4"></span> ISO 20022 Compliant
            </div>
          </div>
        </div>
      </.nx_modal>
    </div>
    """
  end
end
