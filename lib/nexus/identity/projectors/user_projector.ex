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
          org_id: ev.org_id,
          email: ev.email,
          display_name: ev.display_name,
          role: ev.role,
          cose_key: safe_decode64(ev.cose_key),
          credential_id: safe_decode64(ev.credential_id)
        }

        # We use Multi.run to check for existence before inserting.
        # This is the safest way to prevent 'users_email_index' or 'id'
        # unique violations from crashing the entire projector process.
        multi
        |> Ecto.Multi.run(:check_id, fn repo, _ ->
          {:ok, repo.get(User, ev.user_id)}
        end)
        |> Ecto.Multi.run(:check_email, fn repo, _ ->
          {:ok, repo.get_by(User, email: ev.email)}
        end)
        |> Ecto.Multi.run(:user, fn repo, %{check_id: id_exists, check_email: email_exists} ->
          cond do
            id_exists -> {:ok, id_exists}
            email_exists -> {:ok, email_exists}
            true -> repo.insert(User.changeset(%User{}, user_data))
          end
        end)

      :error ->
        # Skip invalid IDs
        multi
    end
  end)

  defp safe_decode64(binary) when is_binary(binary) do
    case Base.decode64(binary) do
      {:ok, decoded} -> decoded
      # Or a placeholder if it's not base64
      :error -> binary
    end
  end

  defp safe_decode64(other), do: other
end
