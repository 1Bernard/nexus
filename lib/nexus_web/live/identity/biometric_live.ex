defmodule NexusWeb.Identity.BiometricLive do
  use NexusWeb, :live_view
  import NexusWeb.Identity.BiometricComponents

  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.App

  @impl true
  def mount(_params, _session, socket) do
    req_host =
      if connected?(socket) do
        get_connect_info(socket, :uri).host
      else
        socket.endpoint.host()
      end

    {:ok,
     assign(socket,
       step: :welcome,
       activeIndex: 0,
       status: "idle",
       progress: 0,
       verification_id: "KYC-#{Base.encode32(:crypto.strong_rand_bytes(5), padding: false)}",
       user_id: Uniq.UUID.uuid7(),
       challenge: nil,
       error_message: nil,
       host: req_host,
       consent_checked: false,
       screening: %{fuzzy: :scanning, ofac: :scanning, pep: :scanning}
     )}
  end

  @impl true
  def handle_event("toggle_consent", _params, socket) do
    {:noreply, assign(socket, consent_checked: !socket.assigns.consent_checked)}
  end

  @impl true
  def handle_event("next_step", %{"step" => step}, socket) do
    new_step = String.to_existing_atom(step)
    activeIndex = step_index(new_step)

    # Prevent progressing to biometric without consent
    if new_step == :biometric && !socket.assigns.consent_checked do
      {:noreply, socket}
    else
      socket =
        if new_step == :biometric do
          challenge = generate_challenge(socket.assigns.host, socket.assigns.user_id)
          assign(socket, challenge: challenge, status: "idle", progress: 0)
        else
          socket
        end

      # Trigger screening simulation when entering verifying step
      if new_step == :verifying do
        Process.send_after(self(), :advance_screening_1, 800)
      end

      {:noreply, assign(socket, step: new_step, activeIndex: activeIndex)}
    end
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    {:noreply, assign(socket, status: "scanning", progress: 0)}
  end

  @impl true
  def handle_event(
        "biometric_complete",
        %{"attestation_object" => att, "client_data_json" => client},
        socket
      ) do
    # This is for Registration. We use a unique email to avoid conflicts
    # in the read-model (UserProjector) during continuous demo testing.
    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: socket.assigns.user_id,
      display_name: "Bernard Ansah",
      email: "bernard+#{Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)}@example.com",
      role: "admin",
      attestation_object: decode_base64_url!(att),
      client_data_json: decode_base64_url!(client)
    }

    case App.dispatch(command) do
      :ok ->
        Process.send_after(self(), :advance_screening_1, 800)
        {:noreply, assign(socket, step: :verifying, status: "success")}

      {:error, reason} ->
        {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
    end
  end

  @impl true
  def handle_event("go_to_dashboard", _params, socket) do
    token = Phoenix.Token.sign(socket.endpoint, "user auth", socket.assigns.user_id)
    {:noreply, redirect(socket, to: ~p"/auth/login?token=#{token}")}
  end

  @impl true
  def handle_event("biometric_reset", params, socket) do
    error = Map.get(params, "error")
    {:noreply, assign(socket, status: "idle", progress: 0, error_message: error)}
  end

  @impl true
  def handle_info(:advance_screening_1, socket) do
    screening = put_in(socket.assigns.screening, [:fuzzy], :passed)
    Process.send_after(self(), :advance_screening_2, 1200)
    {:noreply, assign(socket, screening: screening)}
  end

  @impl true
  def handle_info(:advance_screening_2, socket) do
    screening = put_in(socket.assigns.screening, [:ofac], :clear)
    Process.send_after(self(), :advance_screening_3, 1000)
    {:noreply, assign(socket, screening: screening)}
  end

  @impl true
  def handle_info(:advance_screening_3, socket) do
    screening = put_in(socket.assigns.screening, [:pep], :low_risk)
    # Brief pause to show the final state before automatic transition
    Process.send_after(self(), :go_to_dashboard, 1500)
    {:noreply, assign(socket, screening: screening)}
  end

  @impl true
  def handle_info(:go_to_dashboard, socket) do
    token = Phoenix.Token.sign(socket.endpoint, "user auth", socket.assigns.user_id)
    {:noreply, redirect(socket, to: ~p"/auth/login?token=#{token}")}
  end

  defp step_index(:welcome), do: 0
  defp step_index(:consent), do: 1
  defp step_index(:biometric), do: 2
  defp step_index(:verifying), do: 3
  defp step_index(:success), do: 3
  defp step_index(:error), do: 0

  defp generate_challenge(host, user_id) do
    # Wax.new_registration_challenge() requires both rp_id and origin.
    # In local dev, origin must be http://localhost:4000 or http://127.0.0.1:4000.
    origin =
      if host in ["localhost", "127.0.0.1"], do: "http://#{host}:4000", else: "https://#{host}"

    challenge =
      Nexus.Identity.WebAuthn.new_registration_challenge(
        rp_id: host,
        origin: origin,
        authenticator_selection: %{
          residentKey: "discouraged",
          requireResidentKey: false,
          userVerification: "preferred"
        }
      )

    AuthChallengeStore.store_challenge(user_id, challenge)

    # We only send the raw bytes (Base64URL encoded) to the browser.
    Base.url_encode64(challenge.bytes, padding: false)
  end

  defp decode_base64_url!(string) do
    Base.url_decode64!(string, padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.dark_page class="flex items-center justify-center p-3 overflow-hidden no-select">
      <div class="w-full max-w-md bg-[#14181F] border border-white/[0.06] rounded-[2.2rem] shadow-2xl flex flex-col relative min-h-[680px] backdrop-blur-sm overflow-hidden">
        <%!-- Connection Error Overlay --%>
        <div class="phx-loading:flex hidden absolute inset-0 bg-[#0B0E14]/70 backdrop-blur-sm z-50 flex-col items-center justify-center text-center p-8 transition-all duration-500">
          <div class="w-16 h-16 rounded-3xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center mb-6 shadow-2xl shadow-indigo-500/10">
            <span class="hero-arrow-path w-8 h-8 text-indigo-400 animate-spin"></span>
          </div>
          <h3 class="text-white font-bold text-xl mb-3 tracking-tight">Syncing with Nexus...</h3>
          <p class="text-slate-500 text-sm leading-relaxed max-w-[240px]">
            Negotiating secure handshake. This usually takes a second.
          </p>
        </div>

        <div class="pt-7 px-7 pb-3 flex justify-between items-center">
          <.step_indicators activeIndex={@activeIndex} />
          <.security_badge />
        </div>

        <div id="contentArea" class="flex-1 px-7 pb-7 overflow-y-auto scroll-soft">
          <.step_content
            step={@step}
            status={@status}
            progress={@progress}
            v_id={@verification_id}
            error={@error_message}
            challenge={@challenge}
            consent_checked={@consent_checked}
            screening={@screening}
          />
        </div>

        <div class="border-t border-white/[0.03] px-7 py-5 flex items-center justify-between text-white/20 text-[10px] font-medium tracking-wider">
          <div class="flex items-center gap-2">
            <span class="hero-fingerprint w-3.5 h-3.5"></span>
            <span>ISO 27001:2022</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="hero-shield-check w-3.5 h-3.5"></span>
            <span>GDPR · CCPA</span>
          </div>
        </div>
      </div>

      <%!-- Dev Warning: WebAuthn requires Localhost or strict domains, IP addresses fail in browser --%>
      <div
        :if={@host == "127.0.0.1"}
        class="fixed top-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 bg-rose-500/10 border border-rose-500/20 text-rose-300 px-4 py-2 rounded-xl backdrop-blur-md text-sm shadow-xl max-w-lg w-full"
      >
        <span class="hero-exclamation-triangle w-5 h-5 flex-shrink-0"></span>
        <div class="flex-1">
          <p class="font-bold">WebAuthn Blocked on IP Address</p>
          <p class="text-xs text-rose-300/80">
            Browsers reject IP addresses (127.0.0.1) for biometric credentials. You must use localhost.
          </p>
        </div>
        <a
          href="http://localhost:4000"
          class="shrink-0 bg-rose-500/20 hover:bg-rose-500/30 text-rose-200 px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors"
        >
          Switch to Localhost
        </a>
      </div>
    </.dark_page>
    """
  end
end
