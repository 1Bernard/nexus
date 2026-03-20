defmodule Nexus.Organization.Queries.TenantQuery do
  @moduledoc """
  Unified query interface for Organization Tenant read models.
  """
  alias Nexus.Repo
  alias Nexus.Organization.Projections.Tenant
  alias Nexus.Types

  @doc """
  Returns a tenant by its Org ID.
  """
  @spec get_by_org_id(Types.org_id()) :: Tenant.t() | nil
  def get_by_org_id(org_id) do
    Repo.get_by(Tenant, org_id: org_id)
  end

  @doc """
  Returns the name of an organization by ID, or the ID itself if not found.
  """
  @spec get_name(Types.org_id()) :: String.t() | binary()
  def get_name(org_id) do
    case get_by_org_id(org_id) do
      %Tenant{name: name} -> name
      _ -> org_id
    end
  end
end
