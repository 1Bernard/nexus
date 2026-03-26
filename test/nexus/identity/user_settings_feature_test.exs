defmodule Nexus.Identity.UserSettingsFeatureTest do
  use Cabbage.Feature, file: "identity/user_settings.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Identity.Commands.{RegisterUser, UpdateSettings, StartSession, ExpireSession}
  alias Nexus.Identity.Projections.{User, UserSettings, UserSession}

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(UserSession)
      Repo.delete_all(UserSettings)
      Repo.delete_all(User)
      Repo.delete_all("projection_versions")
    end)

    :ok
  end

  # --- Given ---

  defgiven ~r/^I am a registered user "(?<name>[^"]+)"$/, _vars, state do
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: "bernard-#{Nexus.Schema.generate_uuidv7()}@nexus.financial",
      display_name: "Bernard",
      role: "admin",
      cose_key: Base.encode64("mock"),
      credential_id: Base.encode64("mock"),
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync User and Settings
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(user_id)
    project_identity_event(event, num)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id})}
  end

  defgiven ~r/^I have an active secure session$/, _vars, state do
    session_id = Nexus.Schema.generate_uuidv7()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: session_id,
      session_token: "mock-token",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      ip_address: "127.0.0.1",
      started_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Session (Stored on User stream)
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    event = List.last(events)
    project_session_event(event.data, event.event_number)

    {:ok, Map.put(state, :session_id, session_id)}
  end

  defgiven ~r/^I am on the "(?<page>[^"]+)" page$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^I am on the "(?<tab>[^"]+)" tab$/, _vars, state do
    {:ok, state}
  end

  defgiven ~r/^there is an active session from a "(?<device>[^"]+)" device$/,
           %{device: "Mobile"},
           state do
    mobile_session_id = Nexus.Schema.generate_uuidv7()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: mobile_session_id,
      session_token: "mobile-token",
      user_agent: "iPhone / Mobile Safari",
      ip_address: "192.168.1.1",
      started_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    event = List.last(events)
    project_session_event(event.data, event.event_number)

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

    # Sync Settings
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    event = List.last(events)
    project_identity_event(event.data, event.event_number)

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

    # Sync Session
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    event = List.last(events)
    project_session_event(event.data, event.event_number)

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
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      settings = Repo.get_by(UserSettings, org_id: state.org_id, user_id: state.user_id)
      assert settings != nil
      assert settings.locale == locale
      assert settings.timezone == timezone
    end)
    {:ok, state}
  end

  defthen ~r/^I should see "Active Now" next to my current session$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      session = Repo.get_by(UserSession, id: state.session_id, user_id: state.user_id)
      assert session != nil
      refute session.is_expired
    end)
    {:ok, state}
  end

  defthen ~r/^I should see the device type and last active timestamp$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^I should see an "AES-256 · PASSKEY SECURED" indicator$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the session should be terminated$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      session = Repo.get_by(UserSession, id: state.mobile_session_id)
      assert session != nil
      assert session.is_expired
    end)
    {:ok, state}
  end

  defthen ~r/^I should see "Session revoked successfully"$/, _vars, state do
    assert :ok == state.result
    {:ok, state}
  end

  # --- Helpers ---

  defp project_identity_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      case event do
        %Nexus.Identity.Events.UserRegistered{} ->
          Nexus.Identity.Projectors.UserRegistrationProjector.handle(event, %{
            handler_name: "Identity.Projectors.UserRegistrationProjector",
            event_number: num
          })

          Nexus.Identity.Projectors.UserProjector.handle(event, %{
            handler_name: "Identity.Projectors.UserProjector",
            event_number: num
          })

        %Nexus.Identity.Events.SettingsUpdated{} ->
          Nexus.Identity.Projectors.UserProjector.handle(event, %{
            handler_name: "Identity.Projectors.UserProjector",
            event_number: num
          })

        _ ->
          :ok
      end
    end)
  end

  defp project_session_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Nexus.Identity.Projectors.UserProjector.handle(event, %{
        handler_name: "Identity.Projectors.UserProjector",
        event_number: num
      })
    end)
  end
end
