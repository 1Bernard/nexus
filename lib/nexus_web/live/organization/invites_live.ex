defmodule NexusWeb.Organization.InvitesLive do
  @moduledoc """
  LiveView for accepting a tenant invitation via a signed token link.
  """
  use NexusWeb, :live_view
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Verify the token. A secure token holds the org_id, role, and invited_by context.
    case Phoenix.Token.verify(NexusWeb.Endpoint, "user_invitation", token, max_age: 86400) do
      {:ok, %{org_id: org_id, role: role, invited_by: _invited_by}} ->
        {:ok,
         socket
         |> assign(:page_title, "Accept Invitation")
         |> assign(:token, token)
         |> assign(:org_id, org_id)
         |> assign(:roles, [role])
         |> assign(:valid_token, true)
         |> assign(:form, to_form(%{"display_name" => "", "email" => ""}, as: "registration"))}

      {:error, reason} ->
        Logger.debug("[InvitesLive] Token verify failed: #{inspect(reason)}")
        {:ok,
         socket
         |> assign(:page_title, "Invalid Invitation")
         |> assign(:valid_token, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#020617] flex items-center justify-center p-4 selection:bg-indigo-500/30">
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-[40%] -left-[20%] w-[70%] h-[70%] rounded-full bg-indigo-900/10 blur-[120px]">
        </div>
        <div class="absolute -bottom-[40%] -right-[20%] w-[70%] h-[70%] rounded-full bg-slate-800/20 blur-[120px]">
        </div>
      </div>

      <div class="relative w-full max-w-md">
        <div class="text-center mb-10">
          <h1 class="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-slate-100 to-slate-400 tracking-tight mb-2">
            NEXUS
          </h1>
          <p class="text-slate-500 text-sm font-medium tracking-wide uppercase">
            Corporate Treasury Platform
          </p>
        </div>

        <div class="bg-slate-900 border border-slate-800 rounded-3xl p-8">
          <%= if @valid_token do %>
            <div class="text-center mb-8">
              <div class="mx-auto w-16 h-16 bg-indigo-500/10 border border-indigo-500/20 rounded-2xl flex items-center justify-center mb-4 text-indigo-400">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-8 w-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
                  />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-slate-100 mb-2">Accept Invitation</h2>
              <p class="text-slate-400 text-sm">
                You've been invited to join the organization as a
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-bold bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 uppercase tracking-wider ml-1">
                  {Enum.join(@roles, ", ")}
                </span>
              </p>
            </div>

            <.form for={@form} id="registration-form" phx-submit="register" class="space-y-6">
              <.input
                field={@form[:display_name]}
                type="text"
                label="Full Name"
                placeholder="Jane Doe"
                required
                class="block w-full pl-10 pr-3 py-3 border border-slate-700/50 rounded-xl leading-5 bg-slate-900/50 text-slate-200 placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all sm:text-sm shadow-inner"
              />

              <.input
                field={@form[:email]}
                type="email"
                label="Email Address"
                placeholder="jane@example.com"
                required
                class="block w-full pl-10 pr-3 py-3 border border-slate-700/50 rounded-xl leading-5 bg-slate-900/50 text-slate-200 placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all sm:text-sm shadow-inner"
              />

              <div class="bg-indigo-500/10 border border-indigo-500/20 rounded-xl p-4 flex gap-3 items-start">
                <div class="mt-0.5 text-indigo-400">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="text-xs text-indigo-200/80 leading-relaxed">
                  Next, you will register your device biometrics (Face ID or Touch ID) to enable secure, passwordless authentication for your account.
                </div>
              </div>

              <button
                type="submit"
                class="w-full flex justify-center py-3 px-4 border border-transparent rounded-xl shadow-lg shadow-indigo-500/20 text-sm font-bold text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 focus:ring-offset-slate-900 transition-all"
              >
                Continue to Biometrics
              </button>
            </.form>
          <% else %>
            <div class="text-center py-8">
              <div class="mx-auto w-16 h-16 bg-rose-500/10 border border-rose-500/20 rounded-full flex items-center justify-center mb-6 text-rose-400">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-8 w-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              </div>
              <h2 class="text-xl font-bold text-slate-100 mb-2">Invalid or Expired Link</h2>
              <p class="text-slate-400 text-sm mb-8">
                This invitation link is no longer valid. It may have expired or already been used. Please contact your organization administrator for a new link.
              </p>
              <.link
                href="/auth/login"
                class="inline-flex justify-center py-2 px-4 border border-slate-700/50 rounded-lg shadow-sm text-sm font-bold text-slate-300 bg-slate-800 hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 focus:ring-offset-slate-900 transition-all"
              >
                Return to Login
              </.link>
            </div>
          <% end %>
        </div>

        <p class="mt-8 text-center text-xs text-slate-600 font-medium">
          &copy; {Date.utc_today().year} Nexus Security. All rights reserved.
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("register", %{"registration" => %{"display_name" => name, "email" => email}}, socket) do
    if socket.assigns.valid_token do
      # We encode the registration intent securely for the next step (Biometric Registration)
      # This hands off the decoded org_id and role reliably to `/auth/gate`
      registration_token =
        Phoenix.Token.sign(NexusWeb.Endpoint, "biometric_registration", %{
          org_id: socket.assigns.org_id,
          roles: socket.assigns.roles,
          email: email,
          display_name: name
        })

      {:noreply,
       push_navigate(socket, to: "/auth/gate?intent=register&token=#{registration_token}")}
    else
      {:noreply, socket}
    end
  end
end
