defmodule Nexus.Repo.Migrations.AddGodModeFieldsToTenants do
  use Ecto.Migration

  def change do
    alter table(:organization_tenants) do
      add :suspended_at, :utc_datetime_usec
      add :modules_enabled, :jsonb, default: "[]"
    end
  end
end
