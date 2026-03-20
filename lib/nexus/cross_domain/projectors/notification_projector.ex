defmodule Nexus.CrossDomain.Projectors.NotificationProjector do
  @moduledoc """
  Listens for notification events and updates the cross_domain_notifications table.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "CrossDomain.NotificationProjector",
    repo: Nexus.Repo,
    schema_prefix: "public"

  alias Nexus.CrossDomain.Events.{NotificationCreated, NotificationRead}
  alias Nexus.CrossDomain.Queries.NotificationQuery
  alias Nexus.CrossDomain.Projections.Notification

  project(%NotificationCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :notification,
      %Notification{
        id: event.id,
        org_id: event.org_id,
        user_id: event.user_id,
        type: event.type,
        title: event.title,
        body: event.body,
        metadata: event.metadata,
        created_at: Nexus.Schema.parse_datetime(event.timestamp)
      }, on_conflict: :nothing)
    |> Ecto.Multi.run(:broadcast_unread, fn _repo, _changes ->
      broadcast_unread_count(event.org_id, event.user_id)
      {:ok, nil}
    end)
  end)

  project(%NotificationRead{} = event, _metadata, fn multi ->
    query =
      NotificationQuery.base(event.org_id)
      |> where([n], n.id == ^event.id)

    Ecto.Multi.update_all(multi, :notification, query, set: [read_at: event.read_at])
    |> Ecto.Multi.run(:broadcast_unread, fn _repo, _changes ->
      broadcast_unread_count(event.org_id, event.user_id)
      {:ok, nil}
    end)
  end)

  defp broadcast_unread_count(nil, _user_id), do: :ok
  defp broadcast_unread_count(_org_id, nil), do: :ok

  defp broadcast_unread_count(org_id, user_id) do
    count =
      NotificationQuery.base(org_id)
      |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
      |> Nexus.Repo.aggregate(:count, :id)

    Phoenix.PubSub.broadcast(Nexus.PubSub, "unread_count:user:#{user_id}", {:unread_count, count})
    :ok
  end
end
