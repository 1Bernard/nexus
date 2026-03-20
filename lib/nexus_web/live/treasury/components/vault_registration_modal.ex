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
              <.nx_input
                field={@form[:name]}
                name="vault[name]"
                label="Vault Name"
                placeholder="e.g. JPMorgan Operating"
                required
              />

              <.nx_input
                field={@form[:bank_name]}
                name="vault[bank_name]"
                label="Bank Name"
                placeholder="e.g. JPMorgan Chase"
                required
              />

              <.nx_select field={@form[:currency]} label="Currency" options={@currencies} />

              <.nx_select field={@form[:provider]} label="Provider" options={@providers} />

              <.nx_input
                field={@form[:account_number]}
                name="vault[account_number]"
                label="Account Number"
                placeholder="•••• 1234"
                class="font-mono"
              />

              <.nx_input
                field={@form[:iban]}
                name="vault[iban]"
                label="IBAN (Europe Only)"
                placeholder="GB29..."
                class="font-mono"
              />

              <div class="md:col-span-2 pt-4 border-t border-white/5 space-y-6">
                <div class="flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/5">
                  <div class="flex gap-4 items-center">
                    <div class="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center border border-indigo-500/20">
                      <.icon name="hero-shield-check" class="w-5 h-5 text-indigo-400" />
                    </div>
                    <div>
                      <h5 class="text-sm font-bold text-white">Enforce Multi-Signature Approval</h5>
                      <p class="text-[10px] text-slate-500">
                        Requires multiple authorizers for any fund movement.
                      </p>
                    </div>
                  </div>
                  <.input
                    type="checkbox"
                    field={@form[:requires_multi_sig]}
                    name="vault[requires_multi_sig]"
                    class="rounded-lg bg-slate-900 border-slate-700 text-indigo-500 focus:ring-indigo-500/40 w-6 h-6"
                  />
                </div>

                <.nx_input
                  field={@form[:daily_withdrawal_limit]}
                  name="vault[daily_withdrawal_limit]"
                  label="Institutional Daily Withdrawal Limit"
                  placeholder="e.g. 50000.00"
                  type="number"
                  step="0.01"
                />
              </div>
            </div>

            <div class="pt-6 border-t border-white/5 flex gap-4">
              <.nx_button
                type="button"
                variant="ghost"
                phx-click="close"
                phx-target={@myself}
                class="flex-1 py-4 rounded-2xl"
              >
                Dismiss
              </.nx_button>
              <.nx_button
                type="submit"
                variant="primary"
                class="flex-1 py-4 rounded-2xl shadow-xl shadow-indigo-600/20 group"
              >
                Initiate Registration
                <span class="hero-arrow-right w-4 h-4 group-hover:translate-x-1 transition-transform ml-2">
                </span>
              </.nx_button>
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
