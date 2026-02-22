defmodule Nexus.Organization.Projectors.TenantProjector do
  @moduledoc """
  Projects Organization domain events into the Postgres read model.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Organization.TenantProjector"

  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Projections.Tenant

  project(%TenantProvisioned{} = event, _metadata, fn multi ->
    case Ecto.UUID.cast(event.org_id) do
      {:ok, _id} ->
        Ecto.Multi.insert(
          multi,
          :tenant,
          %Tenant{
            id: event.org_id,
            org_id: event.org_id,
            name: event.name,
            status: "active",
            initial_admin_email: event.initial_admin_email,
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          },
          on_conflict: :nothing,
          conflict_target: :id
        )
        |> Ecto.Multi.run(:broadcast, fn _repo, _changes ->
          Phoenix.PubSub.broadcast(Nexus.PubSub, "tenants", {:tenant_updated, event})
          {:ok, event}
        end)

      :error ->
        multi
    end
  end)
end
