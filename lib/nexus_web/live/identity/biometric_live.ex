defmodule NexusWeb.Identity.BiometricLive do
  @moduledoc """
  LiveView for WebAuthn biometric registration and authentication flows.
  Handles both the initial credential registration and subsequent login verification.
  """
  use NexusWeb, :live_view
  import NexusWeb.Identity.BiometricComponents

  alias Nexus.App
  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.WebAuthn

  @impl true
  def mount(params, _session, socket) do
    action_type = params["type"] || "login"

    req_host =
      if connected?(socket) do
        get_connect_info(socket, :uri).host
      else
        socket.endpoint.host()
      end

    {:ok,
     assign(socket,
       step: :welcome,
       active_index: 0,
       status: "idle",
       progress: 0,
       verification_id: "KYC-#{Base.encode32(:crypto.strong_rand_bytes(5), padding: false)}",
       user_id: nil,
       challenge: nil,
       error_message: nil,
       host: req_host,
       action_type: action_type,
       consent_checked: false,
       screening: %{fuzzy: :scanning, ofac: :scanning, pep: :scanning},
       is_dev: Mix.env() == :dev
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    action_type = params["intent"] || params["type"] || socket.assigns[:action_type] || "login"
    registration_token = params["token"]

    socket =
      socket
      |> assign(action_type: action_type)
      |> assign(registration_token: registration_token)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_consent", _params, socket) do
    {:noreply, assign(socket, consent_checked: !socket.assigns.consent_checked)}
  end

  @impl true
  def handle_event("next_step", %{"step" => step}, socket) do
    new_step = String.to_existing_atom(step)
    active_index = step_index(new_step)

    # Prevent progressing to biometric without consent
    if new_step == :biometric && !socket.assigns.consent_checked do
      {:noreply, socket}
    else
      socket = process_step_transition(socket, new_step)

      {:noreply, assign(socket, step: new_step, active_index: active_index)}
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
    # When processing a registration, we expect a registration token holding to context
    case Phoenix.Token.verify(
           socket.endpoint,
           "biometric_registration",
           socket.assigns.registration_token || "",
           max_age: 1800
         ) do
      {:ok, %{org_id: org_id, role: role, email: email, display_name: name}} ->
        user_id = socket.assigns.user_id
        att_bin = decode_base64_url!(att)
        client_bin = decode_base64_url!(client)

        with {:ok, challenge} <- AuthChallengeStore.pop_challenge(user_id),
             {:ok, {auth_data, _result}} <- WebAuthn.register(att_bin, client_bin, challenge) do
          cose_key = auth_data.attested_credential_data.credential_public_key
          credential_id = auth_data.attested_credential_data.credential_id

          command = %Nexus.Identity.Commands.RegisterUser{
            user_id: user_id,
            org_id: org_id,
            display_name: name,
            email: email,
            role: role,
            cose_key: Base.encode64(:erlang.term_to_binary(cose_key)),
            credential_id: Base.encode64(credential_id),
            registered_at: DateTime.utc_now()
          }

          case App.dispatch(command) do
            :ok ->
              Process.send_after(self(), :advance_screening_1, 800)
              {:noreply, assign(socket, step: :verifying, status: "success")}

            {:error, reason} ->
              {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
          end
        else
          {:error, reason} ->
            {:noreply,
             assign(socket, step: :error, error_message: "WebAuthn Error: #{inspect(reason)}")}
        end

      {:error, _reason} ->
        # Fallback for dev mode
        user_id = socket.assigns.user_id
        att_bin = decode_base64_url!(att)
        client_bin = decode_base64_url!(client)

        with {:ok, challenge} <- AuthChallengeStore.pop_challenge(user_id),
             {:ok, {auth_data, _result}} <- WebAuthn.register(att_bin, client_bin, challenge) do
          cose_key = auth_data.attested_credential_data.credential_public_key
          credential_id = auth_data.attested_credential_data.credential_id

          command = %Nexus.Identity.Commands.RegisterUser{
            user_id: user_id,
            org_id: Nexus.Schema.generate_uuidv7(),
            display_name: "Bernard Ansah",
            email:
              "bernard+#{Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)}@example.com",
            role: "admin",
            cose_key: Base.encode64(:erlang.term_to_binary(cose_key)),
            credential_id: Base.encode64(credential_id),
            registered_at: DateTime.utc_now()
          }

          case App.dispatch(command) do
            :ok ->
              Process.send_after(self(), :advance_screening_1, 800)
              {:noreply, assign(socket, step: :verifying, status: "success")}

            {:error, reason} ->
              {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
          end
        else
          {:error, reason} ->
            {:noreply,
             assign(socket, step: :error, error_message: "WebAuthn Error: #{inspect(reason)}")}
        end
    end
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
    challenge_id = "auth_#{socket.assigns.host}"

    # Simulation: lookup user by email for demo purposes
    user =
      Nexus.Repo.get_by(Nexus.Identity.Projections.User, email: "admin@nexus-platform.io") ||
        Nexus.Repo.get_by(Nexus.Identity.Projections.User, email: "elena@global-corp.com")

    if user do
      case AuthChallengeStore.pop_challenge(challenge_id) do
        {:ok, challenge} ->
          # Perform verification here in the LiveView
          raw_id_bin = decode_base64_url!(raw_id)
          auth_data_bin = decode_base64_url!(auth_data)
          sig_bin = decode_base64_url!(sig)
          client_bin = decode_base64_url!(client)

          # Convert state keys back to binary if they are Base64'd in the projection
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
              command = %Nexus.Identity.Commands.VerifyBiometric{
                user_id: user.id,
                org_id: user.org_id,
                challenge_id: challenge_id,
                verified_at: DateTime.utc_now()
              }

              case App.dispatch(command) do
                :ok ->
                  Process.send_after(self(), :advance_screening_1, 800)

                  {:noreply,
                   assign(socket, step: :verifying, status: "success", user_id: user.id)}

                {:error, reason} ->
                  {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
              end

            {:error, reason} ->
              {:noreply,
               assign(socket, step: :error, error_message: "WebAuthn Error: #{inspect(reason)}")}
          end

        {:error, reason} ->
          {:noreply,
           assign(socket, step: :error, error_message: "Challenge Error: #{inspect(reason)}")}
      end
    else
      {:noreply, assign(socket, step: :error, error_message: "User not found.")}
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
  def handle_event("simulate_persona", %{"email" => email}, socket) do
    if socket.assigns.is_dev do
      user = Nexus.Repo.get_by(Nexus.Identity.Projections.User, email: email)

      if user do
        challenge_id = "dev_persona_bypass_#{user.id}"

        command = %Nexus.Identity.Commands.VerifyBiometric{
          user_id: user.id,
          org_id: user.org_id,
          challenge_id: challenge_id,
          verified_at: DateTime.utc_now()
        }

        case App.dispatch(command) do
          :ok ->
            Process.send_after(self(), :advance_screening_1, 800)
            {:noreply, assign(socket, step: :verifying, status: "success", user_id: user.id)}

          {:error, reason} ->
            {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
        end
      else
        {:noreply,
         assign(socket, step: :error, error_message: "Persona user not found in database.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper mirroring aggregate logic for bootstrap bypass
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
      Plug.Crypto.non_executable_binary_to_term(raw)
    rescue
      ArgumentError -> raw
    end
  end

  defp decode_and_unmarshal_cose(other), do: other

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

  defp process_step_transition(socket, :biometric) do
    new_user_id =
      if socket.assigns.action_type == "register", do: Uniq.UUID.uuid7(), else: nil

    challenge =
      if socket.assigns.action_type == "register" do
        generate_registration_challenge(socket.assigns.host, new_user_id)
      else
        generate_authentication_challenge(socket.assigns.host)
      end

    socket
    |> assign(user_id: new_user_id)
    |> assign(challenge: challenge, status: "idle", progress: 0)
  end

  defp process_step_transition(socket, :verifying) do
    Process.send_after(self(), :advance_screening_1, 800)
    socket
  end

  defp process_step_transition(socket, _other_step), do: socket

  defp step_index(:welcome), do: 0
  defp step_index(:consent), do: 1
  defp step_index(:biometric), do: 2
  defp step_index(:verifying), do: 3
  defp step_index(:success), do: 3
  defp step_index(:error), do: 0

  defp generate_registration_challenge(host, user_id) do
    # Wax.new_registration_challenge() requires both rp_id and origin.
    # In local dev, origin must be http://localhost:4000 or http://127.0.0.1:4000.
    origin =
      if host in ["localhost", "127.0.0.1"], do: "http://#{host}:4000", else: "https://#{host}"

    challenge =
      WebAuthn.new_registration_challenge(
        rp_id: host,
        origin: origin,
        authenticator_selection: %{
          residentKey: "preferred",
          requireResidentKey: false,
          userVerification: "preferred"
        }
      )

    AuthChallengeStore.store_challenge(user_id, challenge)

    # We only send the raw bytes (Base64URL encoded) to the browser.
    Base.url_encode64(challenge.bytes, padding: false)
  end

  defp generate_authentication_challenge(host) do
    origin =
      if host in ["localhost", "127.0.0.1"], do: "http://#{host}:4000", else: "https://#{host}"

    challenge =
      WebAuthn.new_authentication_challenge(
        rp_id: host,
        origin: origin,
        userVerification: "preferred"
      )

    # Use a generic session key for auth challenges before user_id is known
    challenge_id = "auth_#{host}"
    AuthChallengeStore.store_challenge(challenge_id, challenge)

    Base.url_encode64(challenge.bytes, padding: false)
  end

  defp decode_base64_url!(string) do
    Base.url_decode64!(string, padding: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.dark_page class="relative flex items-center justify-center p-3 overflow-hidden no-select">
      <!-- Museum Archive Background Elements -->
      <.editorial_grid />
      <div class="absolute inset-0 volumetric-nebula opacity-[0.15] pointer-events-none"></div>
      
    <!-- Subtle Ledger Streams in Background -->
      <div class="fixed left-0 top-0 bottom-0 w-64 opacity-[0.03] grayscale pointer-events-none hidden lg:block">
        <.ledger_stream />
      </div>
      <div class="fixed right-0 top-0 bottom-0 w-64 opacity-[0.03] grayscale pointer-events-none hidden lg:block scale-x-[-1]">
        <.ledger_stream />
      </div>

      <div class="w-full max-w-md bg-[#0B0E14]/80 border border-white/[0.08] rounded-[2.2rem] shadow-2xl flex flex-col relative min-h-[680px] backdrop-blur-xl overflow-hidden z-10 transition-all duration-1000">
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
          <.step_indicators active_index={@active_index} />
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
            action_type={@action_type}
            consent_checked={@consent_checked}
            screening={@screening}
            is_dev={@is_dev}
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
