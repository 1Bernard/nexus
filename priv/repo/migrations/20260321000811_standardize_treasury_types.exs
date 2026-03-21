defmodule Nexus.Repo.Migrations.StandardizeTreasuryTypes do
  use Ecto.Migration

  def change do
    # 1. Standardize ExposureSnapshots
    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN calculated_at TYPE timestamptz USING calculated_at AT TIME ZONE 'UTC';"
    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN created_at TYPE timestamptz USING created_at AT TIME ZONE 'UTC';"
    execute "ALTER TABLE treasury_exposure_snapshots ALTER COLUMN updated_at TYPE timestamptz USING updated_at AT TIME ZONE 'UTC';"

    # 2. Standardize LiquidityPositions
    execute "ALTER TABLE treasury_liquidity_positions ALTER COLUMN created_at TYPE timestamptz USING created_at AT TIME ZONE 'UTC';"
    execute "ALTER TABLE treasury_liquidity_positions ALTER COLUMN updated_at TYPE timestamptz USING updated_at AT TIME ZONE 'UTC';"
  end
end
