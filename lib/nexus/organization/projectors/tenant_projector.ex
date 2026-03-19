defmodule Nexus.Organization.Projectors.TenantProjector do
  @moduledoc """
  Projects Organization domain events into the Postgres read model.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Organization.TenantProjector"

  alias Nexus.Organization.Events.TenantProvisioned
  alias Nexus.Organization.Events.TenantSuspended
  alias Nexus.Organization.Events.TenantModuleToggled

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
            created_at: Nexus.Schema.utc_now(),
            updated_at: Nexus.Schema.utc_now()
          },
          on_conflict: :nothing,
          conflict_target: :id
        )

      :error ->
        multi
    end
  end)

  project(%TenantSuspended{} = event, _metadata, fn multi ->
    Ecto.Multi.run(multi, :tenant, fn repo, _changes ->
      tenant = repo.get(Tenant, event.org_id)

      if tenant do
        tenant
        |> Ecto.Changeset.change(%{
          status: "SUSPENDED",
          suspended_at: event.suspended_at,
          updated_at: Nexus.Schema.utc_now()
        })
        |> repo.update()
      else
        {:error, :not_found}
      end
    end)
  end)

  project(%TenantModuleToggled{} = event, _metadata, fn multi ->
    Ecto.Multi.run(multi, :tenant, fn repo, _changes ->
      import Ecto.Query
      tenant = repo.one(from(t in Tenant, where: t.org_id == ^event.org_id))

      if tenant do
        modules =
          if event.enabled do
            Enum.uniq([event.module_name | tenant.modules_enabled || []])
          else
            List.delete(tenant.modules_enabled || [], event.module_name)
          end

        tenant
        |> Ecto.Changeset.change(%{modules_enabled: modules})
        |> repo.update()
      else
        {:error, :not_found}
      end
    end)
  end)
end
