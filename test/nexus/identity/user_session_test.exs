defmodule Nexus.Identity.UserSessionTest do
  use Cabbage.Feature, file: "identity/user_sessions.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Identity.Commands.{StartSession, ExpireSession}
  alias Nexus.Identity.Projections.UserSession
  alias Nexus.Identity.Projectors.UserProjector
  alias Nexus.App
  alias Nexus.Repo

  setup do
    org_id = Nexus.Schema.generate_uuidv7()
    user_id = Nexus.Schema.generate_uuidv7()

    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(UserSession)
      Repo.delete_all(Nexus.Identity.Projections.User)
      Repo.delete_all("projection_versions")
    end)

    {:ok, %{org_id: org_id, user_id: user_id}}
  end

  # --- Given ---

  defgiven ~r/^a registered user "(?<email>[^"]+)" exists$/, %{email: email}, state do
    command = %Nexus.Identity.Commands.RegisterUser{
      user_id: state.user_id,
      org_id: state.org_id,
      email: email,
      display_name: "Test User",
      role: "admin",
      cose_key: "mock",
      credential_id: "mock",
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(state.user_id)
    project_identity_event(event, num)

    {:ok, state}
  end

  defgiven ~r/^an active session exists for the user$/, _vars, state do
    session_id = Nexus.Schema.generate_uuidv7()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: session_id,
      session_token: "token-abc",
      user_agent: "Mozilla/5.0",
      ip_address: "127.0.0.1",
      started_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection (Session events are on USER stream)
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    %{data: event, event_number: num} = List.last(events)
    project_session_event(event, num)

    {:ok, Map.put(state, :session_id, session_id)}
  end

  # --- When ---

  defwhen ~r/^I start a new session with device "(?<ua>[^"]+)"$/, %{ua: ua}, state do
    session_id = Nexus.Schema.generate_uuidv7()

    command = %StartSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: session_id,
      session_token: "token-123",
      user_agent: ua,
      ip_address: "127.0.0.1",
      started_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    %{data: event, event_number: num} = List.last(events)
    project_session_event(event, num)

    {:ok, Map.put(state, :session_id, session_id)}
  end

  defwhen ~r/^the session is expired$/, _vars, state do
    command = %ExpireSession{
      org_id: state.org_id,
      user_id: state.user_id,
      session_id: state.session_id,
      expired_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    %{data: event, event_number: num} = List.last(events)
    project_session_event(event, num)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^a new session projection should be created$/, _vars, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      session = Repo.get(UserSession, state.session_id)
      assert session != nil
    end)
    {:ok, state}
  end

  defthen ~r/^the session should be marked as (?<status>active|expired)$/, %{status: status}, state do
    expected_expired = status == "expired"
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      session = Repo.get(UserSession, state.session_id)
      assert session.is_expired == expected_expired
    end)
    {:ok, state}
  end

  defthen ~r/^the session projection should be updated$/, _vars, state do
    {:ok, state}
  end

  # --- Helpers ---

  defp project_identity_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      # Manually call Registration Projector as it's the one handling UserRegistered
      Nexus.Identity.Projectors.UserRegistrationProjector.handle(event, %{
        handler_name: "Identity.UserRegistrationProjector",
        event_number: num
      })
    end)
  end

  defp project_session_event(event, num) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      UserProjector.handle(event, %{
        handler_name: "Identity.UserProjector-#{state_id(event)}",
        event_number: num
      })
    end)
  end

  defp state_id(event) do
    case event do
      %{session_id: id} -> id
      _ -> "generic"
    end
  end
end
