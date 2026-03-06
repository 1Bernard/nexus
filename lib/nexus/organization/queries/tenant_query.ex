defmodule Nexus.Organization.Queries.TenantQuery do
  @moduledoc """
  Unified query interface for Organization Tenant read models.
  """
  alias Nexus.Repo
  alias Nexus.Organization.Projections.Tenant

  @doc """
  Returns a tenant by its Org ID.
  """
  def get_by_org_id(org_id) do
    Repo.get_by(Tenant, org_id: org_id)
  end

  @doc """
  Returns the name of an organization by ID, or the ID itself if not found.
  """
  def get_name(org_id) do
    case get_by_org_id(org_id) do
      %Tenant{name: name} -> name
      _ -> org_id
    end
  end
end
