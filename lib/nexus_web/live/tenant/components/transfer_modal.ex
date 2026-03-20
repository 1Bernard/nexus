defmodule NexusWeb.Tenant.Components.TransferModal do
  @moduledoc """
  Industry-standard 'Transfer Funds' modal component.
  Allows users to specify source/destination currencies and amount.
  """
  use NexusWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"from_currency" => "EUR", "to_currency" => "USD", "amount" => ""}),
       currencies: ["EUR", "USD", "GBP", "JPY", "CHF"]
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"transfer" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params))}
  end

  @impl true
  def handle_event("save", %{"transfer" => params}, socket) do
    if params["amount"] != "" && Decimal.gt?(Decimal.new(params["amount"]), 0) do
      send(self(), {:transfer_submitted, params})
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Please enter a valid amount")}
    end
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_transfer_modal)
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
        class="max-w-md"
      >
        <div class="relative z-10">
          <.modal_header
            title="Transfer Funds"
            subtitle="Institutional Liquidity Portal"
            icon="hero-credit-card"
          />

          <.form
            for={@form}
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-6"
            as={:transfer}
          >
            <div class="grid grid-cols-2 gap-4">
              <.nx_select field={@form[:from_currency]} label="Source Currency" options={@currencies} />

              <.nx_select field={@form[:to_currency]} label="Destination" options={@currencies} />
            </div>

            <.nx_input
              field={@form[:amount]}
              type="number"
              label="Amount"
              placeholder="0.00"
              required
              step="0.01"
              class="text-2xl font-mono"
            >
              <:addon>
                <div class="absolute right-5 top-1/2 -translate-y-1/2 text-xs font-black text-indigo-400/50 uppercase tracking-tighter">
                  {@form[:from_currency].value}
                </div>
              </:addon>
            </.nx_input>

            <div class="pt-4">
              <.nx_button
                type="submit"
                variant="primary"
                class="w-full py-4 rounded-2xl shadow-xl shadow-indigo-600/20 group"
              >
                Confirm Transfer
                <span class="hero-arrow-right w-4 h-4 group-hover:translate-x-1 transition-transform ml-2">
                </span>
              </.nx_button>
            </div>
          </.form>

          <div class="mt-8 flex justify-center gap-6 opacity-30 grayscale pointer-events-none scale-90">
            <div class="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              <span class="hero-shield-check w-4 h-4"></span> AES-256 Encrypted
            </div>
            <div class="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              <span class="hero-bolt w-4 h-4"></span> Instant Settlement
            </div>
          </div>
        </div>
      </.nx_modal>
    </div>
    """
  end
end
