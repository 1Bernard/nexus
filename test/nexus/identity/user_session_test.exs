defmodule Nexus.Identity.UserSessionTest do
  use Nexus.DataCase, async: false

  alias Nexus.Identity.Commands.{StartSession, ExpireSession, UpdateSettings}
  alias Nexus.Identity.Projections.{User, UserSession, UserSettings}
  alias Nexus.App
  alias Nexus.Repo

  setup do
    # Start projectors in test process
    start_supervised!(Nexus.Identity.Projectors.UserRegistrationProjector)
    start_supervised!(Nexus.Identity.Projectors.UserProjector)

    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    # Register user in aggregate first
    :ok = App.dispatch(%Nexus.Identity.Commands.RegisterUser{
      org_id: org_id,
      user_id: user_id,
      email: "test@example.com",
      role: "admin",
      display_name: "Test User",
      cose_key: "dummy",
      credential_id: "dummy",
      registered_at: DateTime.utc_now()
    })

    # Wait for projectors to catch up
    Process.sleep(200)

    %{org_id: org_id, user_id: user_id}
  end

  describe "Session Management" do
    test "Starting a session creates a UserSession projection", %{org_id: org_id, user_id: user_id} do
      session_id = Ecto.UUID.generate()
      command = %StartSession{
        org_id: org_id,
        user_id: user_id,
        session_id: session_id,
        session_token: "token123",
        user_agent: "Mozilla/5.0",
        ip_address: "127.0.0.1",
        started_at: DateTime.utc_now()
      }

      assert :ok = App.dispatch(command)

      # Wait for projector
      Process.sleep(500)

      session = Repo.get(UserSession, session_id)
      assert session
      assert session.user_id == user_id
      assert session.session_token == "token123"
      assert session.user_agent == "Mozilla/5.0"
      assert session.ip_address == "127.0.0.1"
      assert session.is_expired == false
    end

    test "Expiring a session updates the UserSession projection", %{org_id: org_id, user_id: user_id} do
      session_id = Ecto.UUID.generate()
      expired_at = DateTime.utc_now()

      # First start it
      Repo.insert!(%UserSession{
        id: session_id,
        user_id: user_id,
        org_id: org_id,
        session_token: "token123",
        last_active_at: DateTime.utc_now(),
        is_expired: false
      })

      command = %ExpireSession{
        org_id: org_id,
        user_id: user_id,
        session_id: session_id,
        expired_at: expired_at
      }

      assert :ok = App.dispatch(command)

      # Wait for projector
      Process.sleep(500)

      session = Repo.get(UserSession, session_id)
      assert session.is_expired == true
    end
  end

  describe "User Settings" do
    test "Updating settings modifies the UserSettings projection", %{org_id: org_id, user_id: user_id} do
      # Wait a bit more for initial settings creation from RegisterUser
      Process.sleep(500)

      command = %UpdateSettings{
        org_id: org_id,
        user_id: user_id,
        locale: "fr",
        timezone: "Europe/Paris",
        theme: "light",
        notifications_enabled: false,
        updated_at: DateTime.utc_now()
      }

      assert :ok = App.dispatch(command)

      # Wait for projector
      Process.sleep(500)

      settings = Repo.get_by(UserSettings, user_id: user_id)
      assert settings, "Settings should exist"
      assert settings.locale == "fr"
      assert settings.timezone == "Europe/Paris"
      assert settings.theme == "light"
      assert settings.notifications_enabled == false
    end
  end
end
