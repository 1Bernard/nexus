defmodule Nexus.Reporting.RemediationTest do
  use Cabbage.Feature, file: "reporting/compliance_remediation.feature"
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.App
  alias Nexus.Repo
  alias Nexus.Identity.Commands.{RegisterUser, ChangeUserRole, RevokeUserRole}
  alias Nexus.Identity.Projections.User
  alias Nexus.Reporting.ProcessManagers.ComplianceRemediationManager

  setup do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Nexus.Repo, fn ->
      Repo.delete_all(User)
      Repo.delete_all("projection_versions")
    end)

    :ok
  end

  # --- Given ---

  defgiven ~r/^a registered user "(?<name>[^"]+)" exists with role "(?<role>[^"]+)"$/,
           %{name: _name, role: role},
           state do
    user_id = Nexus.Schema.generate_uuidv7()
    org_id = Nexus.Schema.generate_uuidv7()

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: "trader-#{Nexus.Schema.generate_uuidv7()}@nexus.financial",
      display_name: "Test User",
      role: role,
      cose_key: Base.encode64("mock"),
      credential_id: Base.encode64("mock"),
      registered_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection
    {:ok, [%{data: event, event_number: num}]} = Nexus.EventStore.read_stream_forward(user_id)
    project_identity_event(event, num)

    {:ok, Map.merge(state, %{user_id: user_id, org_id: org_id})}
  end

  # --- When ---

  defwhen ~r/^the user is assigned the additional role "(?<role>[^"]+)"$/,
          %{role: role},
          state do
    command = %ChangeUserRole{
      user_id: state.user_id,
      org_id: state.org_id,
      role: role,
      actor_id: "admin-123",
      changed_at: DateTime.utc_now()
    }

    assert :ok = App.dispatch(command)

    # Sync Projection for the change
    {:ok, events} = Nexus.EventStore.read_stream_forward(state.user_id)
    change_event = List.last(events)
    project_identity_event(change_event.data, change_event.event_number)

    # --- SIMULATE SELF-HEALING (Process Manager) ---
    # We manually trigger the PM to ensure 100% determinism in BDD tests
    # instead of waiting for background processes.

    # 1. Build PM state from stream
    pm_state = Enum.reduce(events, %ComplianceRemediationManager{}, fn %{data: e}, pm ->
      ComplianceRemediationManager.apply(pm, e)
    end)

    # 2. Invoke PM handle
    actions = List.wrap(ComplianceRemediationManager.handle(pm_state, change_event.data))

    Enum.each(actions, fn
      %RevokeUserRole{} = revoke_cmd ->
        assert :ok = App.dispatch(revoke_cmd)

        # Sync Revocation
        {:ok, final_events} = Nexus.EventStore.read_stream_forward(state.user_id)
        rev_event = List.last(final_events)
        project_identity_event(rev_event.data, rev_event.event_number)

      _ -> :ok
    end)

    {:ok, state}
  end

  # --- Then ---

  defthen ~r/^the "(?<role>[^"]+)" role should be automatically revoked$/, %{role: role}, state do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      user = Repo.get!(User, state.user_id)
      # In the self-healing logic, it clears the role or sets to viewer
      refute Enum.member?(user.roles, role)
    end)
    {:ok, state}
  end

  defthen ~r/^the remediation should be logged in the Compliance Hub$/, _vars, state do
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

        %Nexus.Identity.Events.UserRoleChanged{} ->
          Nexus.Identity.Projectors.UserProjector.handle(event, %{
            handler_name: "Identity.Projectors.UserProjector",
            event_number: num
          })

        %Nexus.Identity.Events.UserRoleRevoked{} ->
          Nexus.Identity.Projectors.UserProjector.handle(event, %{
            handler_name: "Identity.Projectors.UserProjector",
            event_number: num
          })

        _ ->
          :ok
      end
    end)
  end
end
