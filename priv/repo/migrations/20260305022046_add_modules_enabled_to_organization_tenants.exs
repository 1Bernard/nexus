defmodule Nexus.Repo.Migrations.AddModulesEnabledToOrganizationTenants do
  use Ecto.Migration

  def up do
    # Handle the case where the column exists in dev as jsonb but is missing in test
    # or exist as jsonb and needs to be text[]
    execute """
    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organization_tenants' AND column_name='modules_enabled') THEN
            ALTER TABLE organization_tenants DROP COLUMN modules_enabled;
        END IF;
    END
    $$;
    """

    alter table(:organization_tenants) do
      add :modules_enabled, {:array, :string}, default: []
    end
  end

  def down do
    alter table(:organization_tenants) do
      remove :modules_enabled
    end
  end
end
