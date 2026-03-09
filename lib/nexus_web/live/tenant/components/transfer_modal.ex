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
    <div id={@id} class={if(!@show, do: "hidden")}>
      <div class="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-[#0B0E14]/90 backdrop-blur-3xl transition-all duration-300">
        <div class="absolute inset-0" phx-click="close" phx-target={@myself}></div>

        <div class="w-full max-w-md bg-[#0B0E14] border border-white/10 rounded-[2.5rem] p-8 shadow-2xl relative overflow-hidden animate-in zoom-in-95 duration-200">
          <!-- Background Glow -->
          <div class="absolute -top-24 -right-24 w-48 h-48 rounded-full blur-[80px] bg-indigo-500/10"></div>

          <div class="relative z-10">
            <div class="flex items-center justify-between mb-8">
              <div>
                <h3 class="text-xl font-serif italic font-bold text-white uppercase tracking-tight">
                  Transfer Funds
                </h3>
                <p class="text-slate-400 text-[10px] uppercase tracking-widest font-bold mt-1">
                  Institutional Liquidity Portal
                </p>
              </div>
              <button
                phx-click="close"
                phx-target={@myself}
                class="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10 transition-colors"
              >
                <span class="hero-x-mark w-5 h-5 text-slate-400"></span>
              </button>
            </div>

            <.form
              for={@form}
              phx-change="validate"
              phx-submit="save"
              phx-target={@myself}
              class="space-y-6"
              as={:transfer}
            >
              <div class="grid grid-cols-2 gap-4">
                <div class="space-y-2">
                  <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                    Source Currency
                  </label>
                  <div class="relative group">
                    <select
                      name="transfer[from_currency]"
                      class="w-full bg-white/5 border border-white/10 rounded-2xl px-4 py-3.5 text-sm font-bold text-white focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all appearance-none cursor-pointer group-hover:border-white/20"
                    >
                      <%= for c <- @currencies do %>
                        <option value={c} selected={@form[:from_currency].value == c}>{c}</option>
                      <% end %>
                    </select>
                    <span class="hero-chevron-down w-4 h-4 text-slate-500 absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none"></span>
                  </div>
                </div>

                <div class="space-y-2">
                  <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                    Destination
                  </label>
                  <div class="relative group">
                    <select
                      name="transfer[to_currency]"
                      class="w-full bg-white/5 border border-white/10 rounded-2xl px-4 py-3.5 text-sm font-bold text-white focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all appearance-none cursor-pointer group-hover:border-white/20"
                    >
                      <%= for c <- @currencies do %>
                        <option value={c} selected={@form[:to_currency].value == c}>{c}</option>
                      <% end %>
                    </select>
                    <span class="hero-chevron-down w-4 h-4 text-slate-500 absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none"></span>
                  </div>
                </div>
              </div>

              <div class="space-y-2">
                <label class="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">
                  Amount
                </label>
                <div class="relative group">
                  <input
                    type="number"
                    name="transfer[amount]"
                    value={@form[:amount].value}
                    placeholder="0.00"
                    step="0.01"
                    required
                    class="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-2xl font-mono font-bold text-white placeholder:text-slate-700 focus:ring-2 focus:ring-indigo-500/50 focus:border-indigo-500/50 transition-all group-hover:border-white/20"
                  />
                  <div class="absolute right-5 top-1/2 -translate-y-1/2 text-xs font-black text-indigo-400/50 uppercase tracking-tighter">
                    {@form[:from_currency].value}
                  </div>
                </div>
              </div>

              <div class="pt-4">
                <button
                  type="submit"
                  class="w-full bg-indigo-600 hover:bg-indigo-500 text-white py-4 rounded-2xl font-bold text-sm shadow-xl shadow-indigo-600/20 transition-all active:scale-[0.98] flex items-center justify-center gap-3 group"
                >
                  Confirm Transfer
                  <span class="hero-arrow-right w-4 h-4 group-hover:translate-x-1 transition-transform"></span>
                </button>
              </div>
            </.form>

            <div class="mt-8 flex justify-center gap-6 opacity-30 grayscale pointer-events-none scale-90">
              <div class="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                <span class="hero-shield-check w-4 h-4"></span>
                AES-256 Encrypted
              </div>
              <div class="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                <span class="hero-bolt w-4 h-4"></span>
                Instant Settlement
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
