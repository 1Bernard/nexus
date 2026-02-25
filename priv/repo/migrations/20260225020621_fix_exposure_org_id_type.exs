defmodule Nexus.Repo.Migrations.FixExposureOrgIdType do
  use Ecto.Migration

  def up do
    execute "TRUNCATE treasury_exposure_snapshots;"

    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN org_id TYPE uuid USING org_id::uuid;"
  end

  def down do
    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN org_id TYPE varchar;"
  end
end
