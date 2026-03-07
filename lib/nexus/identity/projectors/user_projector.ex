defmodule Nexus.Identity.Projectors.UserProjector do
  @moduledoc """
  Handles User lifecycle events (role, status) and updates the User projection.
  Decoupled for scalability (Rule 3).
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Identity.Projectors.UserProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.{UserRoleChanged, UserStatusChanged}
  alias Nexus.Identity.Projections.User
  import Ecto.Query

  project(%UserRoleChanged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_role,
      from(u in User, where: u.id == ^event.user_id),
      set: [role: event.role, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
  end)

  project(%UserStatusChanged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :update_status,
      from(u in User, where: u.id == ^event.user_id),
      set: [status: event.status, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
  end)
end
