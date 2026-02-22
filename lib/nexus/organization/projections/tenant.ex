defmodule Nexus.Organization.Projections.Tenant do
  @moduledoc """
  Read-model projection for an existing Organization boundary.
  """
  use Nexus.Schema

  schema "organization_tenants" do
    field :org_id, :binary_id
    field :name, :string
    field :status, :string, default: "active"
    field :initial_admin_email, :string

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :org_id, :name, :status])
    |> validate_required([:id, :org_id, :name])
  end
end
