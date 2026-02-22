defmodule Nexus.Shared.Middleware.TenantGate do
  @moduledoc """
  Commanded Middleware that enforces Multi-Tenancy (Hardware V2 Isolation).

  Intercepts every command dispatched through the Nexus application router.
  Ensures that the `org_id` context is present. Halts the pipeline if missing,
  except for the genesis command `ProvisionOrganization` which bootstraps
  the tenant itself.
  """
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline

  # We allow ProvisionOrganization to bypass the gate since it creates the org_id context.
  def before_dispatch(
        %Pipeline{command: %Nexus.Tenant.Commands.ProvisionOrganization{}} = pipeline
      ) do
    pipeline
  end

  def before_dispatch(%Pipeline{command: command} = pipeline) do
    if Map.has_key?(command, :org_id) and is_binary(Map.get(command, :org_id)) do
      pipeline
    else
      Pipeline.respond(pipeline, {:error, :missing_tenant_context})
      |> Pipeline.halt()
    end
  end

  def after_dispatch(pipeline), do: pipeline
  def after_failure(pipeline), do: pipeline
end
