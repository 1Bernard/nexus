defmodule Nexus.Repo.Migrations.RestoreForecastPrecision do
  use Ecto.Migration

  def up do
    alter table(:treasury_forecast_snapshots) do
      modify :created_at, :utc_datetime_usec, from: :utc_datetime
    end
  end

  def down do
    alter table(:treasury_forecast_snapshots) do
      modify :created_at, :utc_datetime, from: :utc_datetime_usec
    end
  end
end
