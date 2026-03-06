defmodule Nexus.Identity.Projectors.UserRegistrationProjector do
  @moduledoc """
  Handles User registration events and writes the initial User projection.
  Decoupled for scalability (Rule 3).
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Identity.Projectors.UserRegistrationProjector",
    repo: Nexus.Repo,
    consistency: :strong

  alias Nexus.Identity.Events.UserRegistered
  alias Nexus.Identity.Projections.User

  project(%UserRegistered{} = event, _metadata, fn multi ->
    # Guard against stale test data with invalid ID formats
    case Ecto.UUID.cast(event.user_id) do
      {:ok, _uuid} ->
        user_data = %{
          id: event.user_id,
          org_id: event.org_id,
          email: event.email,
          display_name: event.display_name,
          role: event.role,
          cose_key: safe_decode64(event.cose_key),
          credential_id: safe_decode64(event.credential_id)
        }

        project_registration(multi, user_data, event)

      :error ->
        multi
    end
  end)

  defp project_registration(multi, user_data, event) do
    multi
    |> Ecto.Multi.run(:check_id, fn repo, _ ->
      {:ok, repo.get(User, event.user_id)}
    end)
    |> Ecto.Multi.run(:check_email, fn repo, _ ->
      {:ok, repo.get_by(User, email: event.email)}
    end)
    |> Ecto.Multi.run(:user, fn repo, %{check_id: id_exists, check_email: email_exists} ->
      cond do
        id_exists -> {:ok, id_exists}
        email_exists -> {:ok, email_exists}
        true -> repo.insert(User.changeset(%User{}, user_data))
      end
    end)
  end

  defp safe_decode64(binary) when is_binary(binary) do
    case Base.decode64(binary) do
      {:ok, decoded} -> decoded
      :error -> binary
    end
  end

  defp safe_decode64(other), do: other
end
