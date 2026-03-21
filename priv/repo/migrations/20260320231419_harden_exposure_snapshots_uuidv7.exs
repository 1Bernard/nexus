defmodule Nexus.Repo.Migrations.HardenExposureSnapshotsUuidv7 do
  use Ecto.Migration

  def change do
    execute "TRUNCATE treasury_exposure_snapshots;"

    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN id TYPE uuid USING id::uuid;"
    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN org_id TYPE uuid USING org_id::uuid;"

    drop_if_exists index(:treasury_exposure_snapshots, [:subsidiary, :currency])
    create unique_index(:treasury_exposure_snapshots, [:org_id, :subsidiary, :currency])
  end
end
