defmodule NexusWeb.Organization.InvitesLive do
  use NexusWeb, :live_view
  import NexusWeb.Identity.BiometricComponents

  alias Nexus.App
  alias Nexus.Identity.AuthChallengeStore
  alias Nexus.Identity.WebAuthn
  alias Nexus.Organization.Projections.Invitation

  def mount(%{"token" => token}, _session, socket) do
    case Nexus.Repo.get_by(Invitation, invitation_token: token, status: "pending") do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid or expired invitation.")
         |> redirect(to: "/")}

      invitation ->
        req_host =
          if connected?(socket),
            do: get_connect_info(socket, :uri).host,
            else: socket.endpoint.host()

        {:ok,
         assign(socket,
           invitation: invitation,
           step: :welcome,
           active_index: 0,
           status: "idle",
           progress: 0,
           verification_id: "INV-#{String.slice(token, 0, 8)}",
           user_id: nil,
           challenge: nil,
           error_message: nil,
           host: req_host,
           action_type: "register",
           consent_checked: false,
           screening: %{fuzzy: :scanning, ofac: :scanning, pep: :scanning}
         )}
    end
  end

  # Reuse BiometricLive logic for event handling
  def handle_event("toggle_consent", _params, socket) do
    {:noreply, assign(socket, consent_checked: !socket.assigns.consent_checked)}
  end

  def handle_event("next_step", %{"step" => step}, socket) do
    new_step = String.to_existing_atom(step)

    if new_step == :biometric && !socket.assigns.consent_checked do
      {:noreply, socket}
    else
      socket = process_step_transition(socket, new_step)
      {:noreply, assign(socket, step: new_step, active_index: step_index(new_step))}
    end
  end

  def handle_event("biometric_start", _params, socket) do
    {:noreply, assign(socket, status: "scanning", progress: 0)}
  end

  def handle_event(
        "biometric_complete",
        %{"attestation_object" => att, "client_data_json" => client},
        socket
      ) do
    invitation = socket.assigns.invitation

    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: socket.assigns.user_id,
      # Use Org ID from invitation
      org_id: invitation.org_id,
      display_name: "Invited User",
      # Use Email from invitation
      email: invitation.email,
      # Use Role from invitation
      role: invitation.role,
      attestation_object: decode_base64_url!(att),
      client_data_json: decode_base64_url!(client)
    }

    case App.dispatch(command) do
      :ok ->
        # Redeem the invitation
        redeem_cmd = %Nexus.Organization.Commands.RedeemInvitation{
          org_id: invitation.org_id,
          invitation_token: invitation.invitation_token,
          redeemed_by_user_id: socket.assigns.user_id
        }

        # We fire and forget or check success for the redeem command
        App.dispatch(redeem_cmd)

        Process.send_after(self(), :advance_screening_1, 800)
        {:noreply, assign(socket, step: :verifying, status: "success")}

      {:error, reason} ->
        {:noreply, assign(socket, step: :error, error_message: inspect(reason))}
    end
  end

  # Screening progress logic (copied for now, refactor later if needed)
  def handle_info(:advance_screening_1, socket) do
    screening = put_in(socket.assigns.screening, [:fuzzy], :passed)
    Process.send_after(self(), :advance_screening_2, 1200)
    {:noreply, assign(socket, screening: screening)}
  end

  def handle_info(:advance_screening_2, socket) do
    screening = put_in(socket.assigns.screening, [:ofac], :clear)
    Process.send_after(self(), :advance_screening_3, 1000)
    {:noreply, assign(socket, screening: screening)}
  end

  def handle_info(:advance_screening_3, socket) do
    screening = put_in(socket.assigns.screening, [:pep], :low_risk)
    Process.send_after(self(), :go_to_dashboard, 1500)
    {:noreply, assign(socket, screening: screening)}
  end

  def handle_info(:go_to_dashboard, socket) do
    token = Phoenix.Token.sign(socket.endpoint, "user auth", socket.assigns.user_id)
    {:noreply, redirect(socket, to: ~p"/auth/login?token=#{token}")}
  end

  # Helper logic
  defp process_step_transition(socket, :biometric) do
    new_user_id = Uniq.UUID.uuid7()
    challenge = generate_registration_challenge(socket.assigns.host, new_user_id)

    socket
    |> assign(user_id: new_user_id)
    |> assign(challenge: challenge, status: "idle", progress: 0)
  end

  defp process_step_transition(socket, _), do: socket

  defp step_index(:welcome), do: 0
  defp step_index(:consent), do: 1
  defp step_index(:biometric), do: 2
  defp step_index(:verifying), do: 3
  defp step_index(:success), do: 3

  defp generate_registration_challenge(host, user_id) do
    origin =
      if host in ["localhost", "127.0.0.1"], do: "http://#{host}:4000", else: "https://#{host}"

    challenge = WebAuthn.new_registration_challenge(rp_id: host, origin: origin)
    AuthChallengeStore.store_challenge(user_id, challenge)
    Base.url_encode64(challenge.bytes, padding: false)
  end

  defp decode_base64_url!(string), do: Base.url_decode64!(string, padding: false)

  def render(assigns) do
    # Same UI as BiometricLive but with invitation context
    ~H"""
    <.dark_page class="flex items-center justify-center p-3 overflow-hidden no-select">
      <div class="w-full max-w-md bg-[#14181F] border border-white/[0.06] rounded-[2.2rem] shadow-2xl flex flex-col relative min-h-[680px] backdrop-blur-sm overflow-hidden">
        <div class="pt-7 px-7 pb-3 flex justify-between items-center">
          <.step_indicators active_index={@active_index} />
          <div class="bg-indigo-500/10 border border-indigo-500/20 px-3 py-1 rounded-full">
            <span class="text-indigo-400 font-mono text-[10px] uppercase tracking-tighter">
              Invitation Active
            </span>
          </div>
        </div>

        <div id="contentArea" class="flex-1 px-7 pb-7 overflow-y-auto scroll-soft">
          <%= if @step == :welcome do %>
            <div class="flex flex-col items-center text-center mt-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
              <div class="w-20 h-20 rounded-3xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center mb-8 shadow-2xl shadow-indigo-500/10">
                <span class="hero-envelope-open w-10 h-10 text-indigo-400"></span>
              </div>
              <h2 class="text-white font-bold text-3xl mb-4 tracking-tight">Organization Invite</h2>
              <p class="text-slate-400 text-sm leading-relaxed max-w-[280px] mb-8">
                You've been invited to join
                <span class="text-indigo-400 font-bold">{@invitation.org_id}</span>
                as <span class="text-white underline decoration-indigo-500/50"><%= @invitation.role %></span>.
              </p>
              <button
                phx-click="next_step"
                phx-value-step="consent"
                class="w-full bg-white text-[#0B0E14] font-bold py-4 rounded-2xl hover:bg-slate-200 transition-all duration-300 shadow-xl shadow-white/5 active:scale-[0.98]"
              >
                Accept & Secure
              </button>
            </div>
          <% else %>
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
            />
          <% end %>
        </div>
      </div>
    </.dark_page>
    """
  end
end
