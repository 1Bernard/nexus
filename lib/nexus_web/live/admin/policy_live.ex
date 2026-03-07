defmodule NexusWeb.Admin.PolicyLive do
  @moduledoc """
  LiveView for administrators to configure treasury risk policies, transfer thresholds,
  and policy mode settings.
  """
  use NexusWeb, :live_view

  alias Nexus.Treasury
  import NexusWeb.Admin.PolicyComponents

  @impl true
  def mount(_params, _session, socket) do
    org_id = socket.assigns.current_user.org_id
    policy = Treasury.get_treasury_policy(org_id)

    # If policy.mode_thresholds is missing, fallback to defaults
    modes =
      (policy && policy.mode_thresholds) ||
        %{"standard" => "1000000", "strict" => "50000", "relaxed" => "10000000"}

    audits = Treasury.list_policy_audit_logs(org_id)

    socket =
      socket
      |> assign(:page_title, "Treasury Policy Settings")
      |> assign(
        :page_subtitle,
        "Configure risk appetite and threshold limits for the entire organisation"
      )
      |> assign(:modes, modes)
      |> assign(:audits, audits)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"standard" => standard, "strict" => strict, "relaxed" => relaxed},
        socket
      ) do
    # Simply update the assigns so the risk gauge renders the new preview values
    {:noreply,
     assign(socket, :modes, %{"standard" => standard, "strict" => strict, "relaxed" => relaxed})}
  end

  @impl true
  def handle_event(
        "save",
        %{"standard" => standard, "strict" => strict, "relaxed" => relaxed},
        socket
      ) do
    org_id = socket.assigns.current_user.org_id
    email = socket.assigns.current_user.email

    mode_thresholds = %{
      "standard" => standard,
      "strict" => strict,
      "relaxed" => relaxed
    }

    # Dispatch ConfigureModeThresholds command
    cmd = %Nexus.Treasury.Commands.ConfigureModeThresholds{
      policy_id: org_id,
      org_id: org_id,
      mode_thresholds: mode_thresholds,
      actor_email: email,
      configured_at: DateTime.utc_now()
    }

    case Nexus.App.dispatch(cmd, consistency: :strong) do
      :ok ->
        audits = Treasury.list_policy_audit_logs(org_id)

        {:noreply,
         socket
         |> assign(:modes, mode_thresholds)
         |> assign(:audits, audits)
         |> put_flash(:info, "Treasury policy mode thresholds successfully updated.")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to update thresholds. Please contact support.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_container class="px-4 md:px-6">
      <div class="flex items-center justify-between mb-8">
        <.page_header title={@page_title} subtitle={@page_subtitle} />
        <.nx_button variant="outline" size="sm" icon="hero-arrow-left" href="/dashboard">
          Back to Dashboard
        </.nx_button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Main Configuration Side (2/3) -->
        <div class="lg:col-span-2 space-y-6">
          <.dark_card class="p-8 border-indigo-500/10">
            <h3 class="text-sm font-bold text-white mb-8 uppercase tracking-widest flex items-center gap-2">
              <span class="hero-shield-check w-4 h-4 text-indigo-400"></span> Limit Tier Configuration
            </h3>

            <.risk_gauge modes={@modes} />

            <form phx-change="validate" phx-submit="save" class="mt-12 space-y-8">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                <!-- Strict Mode -->
                <div>
                  <div class="flex items-center gap-2 mb-3">
                    <div class="w-2 h-2 rounded-full bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.4)]">
                    </div>
                    <label class="block text-[10px] font-black text-slate-500 uppercase tracking-widest">
                      Strict Limit
                    </label>
                  </div>
                  <div class="relative group">
                    <span class="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 font-black group-focus-within:text-rose-400 transition-colors">
                      €
                    </span>
                    <input
                      type="number"
                      name="strict"
                      value={@modes["strict"]}
                      required
                      min="0"
                      class="w-full bg-slate-900/80 border border-white/5 rounded-xl py-3 pl-8 pr-4 text-white font-mono text-base focus:outline-none focus:border-rose-500/50 focus:ring-1 focus:ring-rose-500/50 transition-all placeholder:text-slate-700"
                    />
                  </div>
                  <p class="mt-3 text-[10px] text-slate-500 leading-relaxed italic">
                    Multi-SIG enforced above this baseline.
                  </p>
                </div>

    <!-- Standard Mode -->
                <div>
                  <div class="flex items-center gap-2 mb-3">
                    <div class="w-2 h-2 rounded-full bg-amber-500 shadow-[0_0_8px_rgba(245,158,11,0.4)]">
                    </div>
                    <label class="block text-[10px] font-black text-slate-500 uppercase tracking-widest">
                      Standard Limit
                    </label>
                  </div>
                  <div class="relative group">
                    <span class="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 font-black group-focus-within:text-amber-400 transition-colors">
                      €
                    </span>
                    <input
                      type="number"
                      name="standard"
                      value={@modes["standard"]}
                      required
                      min="0"
                      class="w-full bg-slate-900/80 border border-white/5 rounded-xl py-3 pl-8 pr-4 text-white font-mono text-base focus:outline-none focus:border-amber-500/50 focus:ring-1 focus:ring-amber-500/50 transition-all"
                    />
                  </div>
                  <p class="mt-3 text-[10px] text-slate-500 leading-relaxed italic">
                    Step-up auth / hardware key required.
                  </p>
                </div>

    <!-- Relaxed Mode -->
                <div>
                  <div class="flex items-center gap-2 mb-3">
                    <div class="w-2 h-2 rounded-full bg-indigo-500 shadow-[0_0_8px_rgba(99,102,241,0.4)]">
                    </div>
                    <label class="block text-[10px] font-black text-slate-500 uppercase tracking-widest">
                      Relaxed Limit
                    </label>
                  </div>
                  <div class="relative group">
                    <span class="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 font-black group-focus-within:text-indigo-400 transition-colors">
                      €
                    </span>
                    <input
                      type="number"
                      name="relaxed"
                      value={@modes["relaxed"]}
                      required
                      min="0"
                      class="w-full bg-slate-900/80 border border-white/5 rounded-xl py-3 pl-8 pr-4 text-white font-mono text-base focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/50 transition-all"
                    />
                  </div>
                  <p class="mt-3 text-[10px] text-slate-500 leading-relaxed italic">
                    Unrestricted operation flow.
                  </p>
                </div>
              </div>

              <div class="mt-12 pt-8 border-t border-white/5 flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-full bg-rose-500/10 flex items-center justify-center">
                    <span class="hero-exclamation-triangle w-4 h-4 text-rose-500"></span>
                  </div>
                  <span class="text-[10px] text-slate-400 font-bold uppercase tracking-widest leading-none">
                    Action is irreversible & audit logged
                  </span>
                </div>
                <button
                  type="submit"
                  class="bg-indigo-600 hover:bg-indigo-500 text-white px-10 py-3 rounded-xl font-bold text-sm shadow-xl shadow-indigo-600/20 transition-all active:scale-95 flex items-center gap-2"
                >
                  <span class="hero-shield-check w-4 h-4"></span> Persist Policy Thresholds
                </button>
              </div>
            </form>
          </.dark_card>
        </div>

    <!-- Audit/History Side (1/3) -->
        <div class="h-full">
          <.dark_card class="p-6 h-full border-white/5 flex flex-col min-h-[500px]">
            <.audit_panel audits={@audits} />
          </.dark_card>
        </div>
      </div>
    </.page_container>
    """
  end
end
