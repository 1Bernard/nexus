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
    socket = assign(socket, assigns)

    socket =
      cond do
        # Modal is being opened fresh — generate a challenge
        socket.assigns[:show] && !socket.assigns.challenge ->
          maybe_generate_challenge(socket)

        # Modal is being hidden — reset all state so next open is clean
        !socket.assigns[:show] ->
          assign(socket,
            status: "idle",
            progress: 0,
            challenge: nil,
            error_message: nil
          )

        true ->
          socket
      end

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
    user = socket.assigns.current_user

    with {:ok, challenge} <- AuthChallengeStore.pop_challenge(challenge_id) do
      # Perform verification here in the Component
      raw_id_bin = decode_base64_url!(raw_id)
      auth_data_bin = decode_base64_url!(auth_data)
      sig_bin = decode_base64_url!(sig)
      client_bin = decode_base64_url!(client)

      # Convert state keys back to binary if they are Base64'd
      credential_id_bin = decode_or_raw(user.credential_id)
      cose_key_bin = decode_and_unmarshal_cose(user.cose_key)

      # Skip verification for bootstrap user if applicable
      is_bootstrap = bootstrap_user?(user.cose_key, user.credential_id)

      verification_result =
        if is_bootstrap do
          {:ok, :bootstrap}
        else
          WebAuthn.authenticate(
            raw_id_bin,
            auth_data_bin,
            sig_bin,
            client_bin,
            challenge,
            [{credential_id_bin, cose_key_bin}]
          )
        end

      case verification_result do
        {:ok, _} ->
          command = %Nexus.Identity.Commands.VerifyStepUp{
            user_id: user.id,
            org_id: user.org_id,
            challenge_id: challenge_id,
            action_id: socket.assigns.action_id,
            verified_at: DateTime.utc_now()
          }

          case App.dispatch(command) do
            :ok ->
              send(self(), {:step_up_success, socket.assigns.action_id})
              {:noreply, assign(socket, status: "success", progress: 100)}

            {:error, reason} ->
              {:noreply, assign(socket, status: "idle", error_message: inspect(reason))}
          end

        {:error, reason} ->
          {:noreply,
           assign(socket, status: "idle", error_message: "WebAuthn Error: #{inspect(reason)}")}
      end
    else
      {:error, reason} ->
        {:noreply,
         assign(socket, status: "idle", error_message: "Challenge Error: #{inspect(reason)}")}
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

  # Helpers mirroring aggregate logic for bootstrap bypass and decoding
  defp bootstrap_user?(cose_key_bin, cred_id) do
    cose_key_bin in [
      "BOOTSTRAP_PLACEHOLDER",
      "bootstrap_cose_key",
      Base.encode64("bootstrap_cose_key")
    ] or
      cred_id in [
        "BOOTSTRAP_PLACEHOLDER",
        "bootstrap_credential_id",
        Base.encode64("bootstrap_credential_id")
      ]
  end

  defp decode_or_raw(nil), do: nil

  defp decode_or_raw(string) when is_binary(string) do
    case Base.decode64(string, padding: false) do
      {:ok, decoded} -> decoded
      :error -> string
    end
  end

  defp decode_or_raw(other), do: other

  defp decode_and_unmarshal_cose(nil), do: nil

  defp decode_and_unmarshal_cose(binary) when is_binary(binary) do
    raw = decode_or_raw(binary)

    try do
      :erlang.binary_to_term(raw)
    rescue
      ArgumentError -> raw
    end
  end

  defp decode_and_unmarshal_cose(other), do: other

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
          <div class={[
            "absolute -top-24 -left-24 w-48 h-48 rounded-full blur-[80px]",
            if(@status == "success",
              do: "bg-emerald-500/20",
              else: "bg-indigo-500/10"
            )
          ]}>
          </div>

          <%= if @status == "success" do %>
            <%!-- Success screen --%>
            <div class="relative z-10 flex flex-col items-center gap-6 py-6">
              <div class="w-20 h-20 rounded-full bg-emerald-500/10 ring-1 ring-emerald-500/30 flex items-center justify-center animate-in zoom-in-75 duration-300">
                <span class="hero-check-circle w-10 h-10 text-emerald-400"></span>
              </div>
              <div>
                <h3 class="text-xl font-serif italic font-bold text-white tracking-tight">
                  Identity Verified
                </h3>
                <p class="text-emerald-400/80 text-xs mt-2 font-mono tracking-widest uppercase">
                  Authorizing transfer…
                </p>
              </div>
              <div class="flex gap-1.5">
                <span
                  class="w-2 h-2 rounded-full bg-emerald-400 animate-bounce"
                  style="animation-delay: 0ms"
                >
                </span>
                <span
                  class="w-2 h-2 rounded-full bg-emerald-400 animate-bounce"
                  style="animation-delay: 150ms"
                >
                </span>
                <span
                  class="w-2 h-2 rounded-full bg-emerald-400 animate-bounce"
                  style="animation-delay: 300ms"
                >
                </span>
              </div>
            </div>
          <% else %>
            <%!-- Challenge screen --%>
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
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
