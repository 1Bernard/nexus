defmodule Nexus.Repo.Migrations.FixForecastPrecision do
  use Ecto.Migration

  def up do
    alter table(:treasury_forecast_snapshots) do
      modify :generated_at, :naive_datetime_usec, from: :naive_datetime
      modify :created_at, :utc_datetime_usec, from: :utc_datetime
    end
  end

  def down do
    alter table(:treasury_forecast_snapshots) do
      modify :generated_at, :naive_datetime, from: :naive_datetime_usec
      modify :created_at, :utc_datetime, from: :utc_datetime_usec
    end
  end
end
