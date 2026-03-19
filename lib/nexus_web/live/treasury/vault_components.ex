defmodule NexusWeb.Treasury.VaultComponents do
  @moduledoc """
  High-fidelity UI components for the Vault Center.
  """
  use Phoenix.Component
  import NexusWeb.CoreComponents
  import NexusWeb.FormatHelpers

  @doc """
  A high-fidelity card representing a physical bank account (Vault).
  """
  attr :vault, :any, required: true
  attr :on_sync, :any, default: nil

  def vault_card(assigns) do
    ~H"""
    <div class="group relative bg-[#131722]/50 border border-slate-800/60 rounded-2xl p-6 hover:bg-[#161B28] hover:border-indigo-500/30 hover:shadow-[0_0_30px_rgba(99,102,241,0.1)] transition-all duration-300">
      <%!-- Provider Badge & Sync Pulse --%>
      <div class="flex justify-between items-start mb-6">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center border border-white/5">
            <.provider_logo provider={@vault.provider} />
          </div>
          <div>
            <h4 class="text-sm font-bold text-white tracking-tight">{@vault.name}</h4>
            <p class="text-[10px] text-slate-500 uppercase tracking-widest font-bold">{@vault.bank_name}</p>
          </div>
        </div>
        <div class="flex flex-col items-end gap-2">
          <.status_badge status={@vault.status} />
          <div :if={@vault.status == "active"} class="flex items-center gap-1.5">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span class="text-[9px] text-emerald-500/80 font-mono uppercase tracking-tighter">Live Connection</span>
          </div>
        </div>
      </div>

      <%!-- Balance Center --%>
      <div class="mb-6">
        <p class="text-[10px] text-slate-500 uppercase tracking-[0.2em] font-bold mb-1">Available Liquidity</p>
        <div class="flex items-baseline gap-2">
          <span class="text-3xl font-black text-white tracking-tighter">
            {format_currency(@vault.balance, currency: @vault.currency)}
          </span>
          <span class="text-xs font-bold text-slate-500">{@vault.currency}</span>
        </div>
      </div>

      <%!-- Metadata Grid --%>
      <div class="grid grid-cols-2 gap-4 pt-4 border-t border-white/5">
        <div>
          <p class="text-[9px] text-slate-600 uppercase tracking-widest font-bold mb-1">Account</p>
          <p class="text-xs text-slate-400 font-mono tracking-tighter">
            {@vault.account_number || @vault.iban || "•••• 4421"}
          </p>
        </div>
        <div class="text-right">
          <p class="text-[9px] text-slate-600 uppercase tracking-widest font-bold mb-1">Last Sync</p>
          <p class="text-xs text-slate-400 font-mono tracking-tighter">
            {format_relative_time(@vault.updated_at)}
          </p>
        </div>
      </div>

      <%!-- Action Overlay (Hover) --%>
      <div class="absolute inset-0 bg-indigo-600/5 opacity-0 group-hover:opacity-100 transition-opacity rounded-2xl pointer-events-none"></div>

      <%!-- Action Buttons --%>
      <div class="absolute top-6 right-6 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <button
          phx-click="sync_vault"
          phx-value-id={@vault.id}
          class="p-2 rounded-lg bg-slate-800/80 border border-white/5 text-slate-400 hover:text-indigo-400 hover:border-indigo-500/30 transition-all active:scale-95"
          title="Sync Balance"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  defp status_badge(%{status: "active"} = assigns) do
    ~H"""
    <span class="px-2 py-0.5 rounded text-[9px] font-bold uppercase tracking-widest bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
      Active
    </span>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class="px-2 py-0.5 rounded text-[9px] font-bold uppercase tracking-widest bg-slate-800 text-slate-400 border border-slate-700">
      {String.capitalize(assigns.status)}
    </span>
    """
  end

  defp provider_logo(%{provider: "paystack"} = assigns) do
    ~H"""
    <img src="/images/providers/paystack.png" class="w-6 h-6 grayscale hover:grayscale-0 transition-all" alt="Paystack" />
    """
  end

  defp provider_logo(assigns) do
    ~H"""
    <span class="hero-building-library w-5 h-5 text-slate-400"></span>
    """
  end
end
