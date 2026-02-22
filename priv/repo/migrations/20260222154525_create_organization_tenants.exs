defmodule Nexus.Repo.Migrations.CreateOrganizationTenants do
  use Ecto.Migration

  def change do
    create table(:organization_tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :initial_admin_email, :string, null: false

      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:organization_tenants, [:org_id])
    create unique_index(:organization_tenants, [:name])
  end
end
