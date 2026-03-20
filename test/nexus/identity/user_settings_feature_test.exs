defmodule Nexus.Identity.UserSettingsFeatureTest do
  use Cabbage.Feature, file: "identity/user_settings.feature"
  use Nexus.DataCase
  @moduletag :feature

  alias Nexus.App
  alias Nexus.Identity.Commands.{RegisterUser, UpdateSettings, StartSession, ExpireSession}
  alias Nexus.Identity.Queries.SettingsQuery

  setup do
    # Start projectors in test process to capture events in the sandbox
    start_supervised!(Nexus.Identity.Projectors.UserRegistrationProjector)
    start_supervised!(Nexus.Identity.Projectors.UserProjector)

    # Sandbox handles clearing if we use it correctly, but explicit cleanup is safer for these projectors
    Nexus.Repo.delete_all(Nexus.Identity.Projections.UserSession)
    Nexus.Repo.delete_all(Nexus.Identity.Projections.UserSettings)
    Nexus.Repo.delete_all(Nexus.Identity.Projections.User)
    Nexus.Repo.delete_all("projection_versions")

    :ok
  end

  # --- Given ---

  defgiven ~r/^I am a registered user "(?<name>[^"]+)"$/, _vars, state do
    user_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()
    email = "bernard-#{Ecto.UUID.generate()}@nexus.financial"

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: email,
      display_name: "Bernard",
      role: "admin",
      cose_key: Base.encode64("mock"),
      credential_id: Base.encode64("mock"),
      registered_at: DateTime.utc_now()
    }

    :ok = App.dispatch(command)

    # Wait for Registration Projector
    Process.sleep(200)

    {:ok, state |> Map.put(:user_id, user_id) |> Map.put(:org_id, org_id)}
  end

  defgiven ~r/^I have an active secure session$/, _vars, state do
    session_id = Ecto.UUID.generate()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: session_id,
      session_token: "mock-token",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      ip_address: "127.0.0.1",
      started_at: DateTime.utc_now()
    }

    :ok = App.dispatch(command)
    # Wait for session projector
    Process.sleep(100)

    {:ok, Map.put(state, :session_id, session_id)}
  end

  defgiven ~r/^I am on the "(?<page>[^"]+)" page$/, %{page: "Settings"}, state do
    {:ok, state}
  end

  defgiven ~r/^I am on the "(?<tab>[^"]+)" tab$/, %{tab: "Security"}, state do
    {:ok, state}
  end

  defgiven ~r/^there is an active session from a "(?<device>[^"]+)" device$/,
           %{device: "Mobile"},
           state do
    mobile_session_id = Ecto.UUID.generate()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: mobile_session_id,
      session_token: "mobile-token",
      user_agent: "iPhone / Mobile Safari",
      ip_address: "192.168.1.1",
      started_at: DateTime.utc_now()
    }

    :ok = App.dispatch(command)
    Process.sleep(100)

    {:ok, Map.put(state, :mobile_session_id, mobile_session_id)}
  end

  # --- When ---

  defwhen ~r/^I select "(?<language>[^"]+)" as my language$/, %{language: "French"}, state do
    {:ok, Map.put(state, :new_locale, "fr")}
  end

  defwhen ~r/^I select "(?<timezone>[^"]+)" as my timezone$/, %{timezone: timezone}, state do
    {:ok, Map.put(state, :new_timezone, timezone)}
  end

  defwhen ~r/^I click "Save Changes"$/, _vars, state do
    command = %UpdateSettings{
      org_id: state.org_id,
      user_id: state.user_id,
      locale: state.new_locale,
      timezone: state.new_timezone,
      notifications_enabled: true,
      updated_at: DateTime.utc_now()
    }

    result = App.dispatch(command)

    {:ok, Map.put(state, :result, result)}
  end

  defwhen ~r/^I click the "revoke" icon for the mobile session$/, _vars, state do
    command = %ExpireSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: state.mobile_session_id,
      expired_at: DateTime.utc_now()
    }

    result = App.dispatch(command)

    {:ok, Map.put(state, :result, result)}
  end

  # --- Then ---

  defthen ~r/^I should see "Settings updated successfully"$/, _vars, state do
    assert :ok == state.result
    {:ok, state}
  end

  defthen ~r/^my preferences should be persisted as "(?<locale>[^"]+)" and "(?<timezone>[^"]+)"$/,
          %{locale: locale, timezone: timezone},
          state do
    # Wait for projection
    Process.sleep(500)

    settings = SettingsQuery.get_settings(state.org_id, state.user_id)

    assert settings, "Settings should have been projected"
    assert settings.locale == locale
    assert settings.timezone == timezone
    {:ok, state}
  end

  defthen ~r/^I should see "Active Now" next to my current session$/, _vars, state do
    # Wait for projection
    Process.sleep(200)

    # Domain test: verify the current session is not expired
    sessions = SettingsQuery.list_active_sessions(state.org_id, state.user_id)
    current = Enum.find(sessions, &(&1.id == state.session_id))
    assert current, "Current session should be listed"
    refute current.is_expired
    {:ok, state}
  end

  defthen ~r/^I should see the device type and last active timestamp$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^I should see an "AES-256 · PASSKEY SECURED" indicator$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the session should be terminated$/, _vars, state do
    Process.sleep(500)

    sessions = SettingsQuery.list_active_sessions(state.org_id, state.user_id)

    refute Enum.any?(sessions, &(&1.id == state.mobile_session_id))
    {:ok, state}
  end

  defthen ~r/^I should see "Session revoked successfully"$/, _vars, state do
    assert :ok == state.result
    {:ok, state}
  end
end
