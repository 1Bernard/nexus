defmodule NexusWeb.Tenant.Components.StepUpModal do
  @moduledoc """
  High-fidelity Step-Up Authorization modal.
  Encapsulates the WebAuthn flow for secondary biometric verification.
  """
  use NexusWeb, :live_component
  import NexusWeb.Identity.BiometricComponents

  alias Nexus.App
  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.WebAuthn

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       status: "idle",
       progress: 0,
       challenge: nil,
       error_message: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    # When the modal is first opened or updated with a new action
    socket =
      socket
      |> assign(assigns)
      |> maybe_generate_challenge()

    {:ok, socket}
  end

  defp maybe_generate_challenge(socket) do
    if socket.assigns[:show] && !socket.assigns.challenge do
      host = socket.assigns.host

      origin =
        if host in ["localhost", "127.0.0.1"], do: "http://#{host}:4000", else: "https://#{host}"

      challenge =
        WebAuthn.new_authentication_challenge(
          rp_id: host,
          origin: origin,
          userVerification: "preferred"
        )

      # Store challenge with a combined key for step-up
      challenge_id = "step_up_#{socket.assigns.current_user.id}"
      AuthChallengeStore.store_challenge(challenge_id, challenge)

      assign(socket, challenge: Base.url_encode64(challenge.bytes, padding: false))
    else
      socket
    end
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    {:noreply, assign(socket, status: "scanning", progress: 0)}
  end

  @impl true
  def handle_event("biometric_reset", _params, socket) do
    {:noreply, assign(socket, status: "idle", progress: 0)}
  end

  @impl true
  def handle_event(
        "biometric_login",
        %{
          "raw_id" => raw_id,
          "authenticator_data" => auth_data,
          "client_data_json" => client,
          "signature" => sig
        },
        socket
      ) do
    challenge_id = "step_up_#{socket.assigns.current_user.id}"

    command = %Nexus.Identity.Commands.VerifyStepUp{
      user_id: socket.assigns.current_user.id,
      org_id: socket.assigns.current_user.org_id,
      challenge_id: challenge_id,
      action_id: socket.assigns.action_id,
      raw_id: decode_base64_url!(raw_id),
      authenticator_data: decode_base64_url!(auth_data),
      signature: decode_base64_url!(sig),
      client_data_json: decode_base64_url!(client)
    }

    case App.dispatch(command) do
      :ok ->
        send(self(), {:step_up_success, socket.assigns.action_id})
        {:noreply, assign(socket, status: "success", progress: 100)}

      {:error, reason} ->
        {:noreply, assign(socket, status: "idle", error_message: inspect(reason))}
    end
  end

  @impl true
  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), :close_step_up)
    {:noreply, socket}
  end

  defp decode_base64_url!(string), do: Base.url_decode64!(string, padding: false)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class={if(!@show, do: "hidden")}>
      <div class="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-[#0B0E14]/90 backdrop-blur-3xl">
        <%!-- Backdrop capture to prevent "goes off" syndrome --%>
        <div class="absolute inset-0" phx-click={JS.push("noop", target: @myself)}></div>

        <div class="w-full max-w-sm bg-[#0B0E14] border border-white/10 rounded-[2.5rem] p-8 shadow-2xl relative overflow-hidden flex flex-col items-center text-center animate-in zoom-in-95 duration-200">
          <!-- Background Glow -->
          <div class="absolute -top-24 -left-24 w-48 h-48 bg-indigo-500/10 rounded-full blur-[80px]">
          </div>

          <div class="mb-6 relative z-10">
            <div class="w-12 h-12 bg-indigo-500/10 rounded-2xl flex items-center justify-center mb-3 ring-1 ring-indigo-500/30 mx-auto">
              <span class="hero-shield-check w-6 h-6 text-indigo-400"></span>
            </div>
            <h3 class="text-xl font-serif italic font-bold text-white uppercase tracking-tight">
              Step-Up Authorization
            </h3>
            <p class="text-slate-400 text-xs mt-2 px-4 leading-relaxed">
              A high-value action has been requested. Physical biometric verification is required.
            </p>
          </div>

          <div
            id={"step-up-container-#{@id}"}
            class="w-full flex flex-col items-center relative z-10"
            data-challenge={@challenge}
            data-action="login"
          >
            <.sensor_ring status={@status} progress={@progress} target={@myself} />

            <div
              id="biometricHint"
              phx-update="ignore"
              class="h-6 text-[10px] font-mono text-slate-500 mt-2"
            >
              <%= if @error_message do %>
                <span class="text-rose-400">Verification Error: {@error_message}</span>
              <% else %>
                <span>⬇️ scan fingerprint to authorize ⬇️</span>
              <% end %>
            </div>
          </div>

          <div class="mt-8 w-full relative z-10">
            <button
              phx-click="close_modal"
              phx-target={@myself}
              type="button"
              class="text-slate-500 text-[10px] uppercase font-bold tracking-[0.2em] hover:text-slate-300 transition-colors p-4"
            >
              [ Cancel Transaction ]
            </button>
          </div>
          
    <!-- Security Primitives -->
          <div class="mt-8 flex gap-4 opacity-30 grayscale scale-75">
            <.security_badge />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
