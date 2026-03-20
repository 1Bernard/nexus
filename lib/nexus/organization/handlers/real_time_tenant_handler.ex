defmodule Nexus.Organization.Handlers.RealTimeTenantHandler do
  @moduledoc """
  Handles real-time PubSub notifications for Organization domain events.
  Decoupled from TenantProjector (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Organization.Handlers.RealTimeTenantHandler",
    consistency: :eventual

  alias Nexus.Organization.Events.{TenantProvisioned, TenantSuspended, TenantModuleToggled}

  @spec handle(TenantProvisioned.t() | TenantSuspended.t() | TenantModuleToggled.t(), map()) ::
          :ok
  def handle(%TenantProvisioned{} = event, _metadata) do
    Phoenix.PubSub.broadcast(Nexus.PubSub, "tenants", {:tenant_updated, event})
    :ok
  end

  def handle(%TenantSuspended{} = event, _metadata) do
    Phoenix.PubSub.broadcast(Nexus.PubSub, "tenants", {:tenant_updated, event})
    :ok
  end

  def handle(%TenantModuleToggled{} = event, _metadata) do
    Phoenix.PubSub.broadcast(Nexus.PubSub, "tenants", {:tenant_updated, event})
    :ok
  end

  def handle(_event, _metadata), do: :ok
end
