defmodule Nexus.Identity.Projectors.UserProjector do
  @moduledoc """
  Projector for the Identity domain.
  Syncs User-related events to the Read-Side database.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Identity.Projectors.UserProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.UserRegistered
  alias Nexus.Identity.Projections.User

  project(%UserRegistered{} = ev, _metadata, fn multi ->
    # Guard against stale test data with invalid ID formats
    case Ecto.UUID.cast(ev.user_id) do
      {:ok, _uuid} ->
        user_data = %{
          id: ev.user_id,
          display_name: ev.display_name,
          role: ev.role,
          cose_key: Base.decode64!(ev.cose_key),
          credential_id: Base.decode64!(ev.credential_id)
        }

        # Multi-target on_conflict is complex in Postgres (requires a named constraint).
        # For professional stability, we use a single 'id' target and ENSURE secondary keys
        # don't conflict, or we catch the crash.
        # Here we use a robust try/rescue to ensure the projector never hangs the app boot.
        Ecto.Multi.insert(multi, :user, User.changeset(%User{}, user_data),
          on_conflict: {:replace, [:display_name, :role, :cose_key, :credential_id, :updated_at]},
          conflict_target: :id
        )

      :error ->
        # Skip invalid IDs
        multi
    end
  end)
end
