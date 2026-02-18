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
          email: ev.email,
          role: ev.role,
          public_key: ev.public_key
        }

        # Use upsert to handle legacy test data and ensure idempotency
        Ecto.Multi.insert(multi, :user, User.changeset(%User{}, user_data),
          on_conflict: {:replace, [:email, :role, :public_key, :updated_at]},
          conflict_target: :id
        )

      :error ->
        # Skip invalid IDs
        multi
    end
  end)
end
