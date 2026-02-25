defmodule Nexus.Repo.Migrations.CreateMarketTicks do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"

    create table(:treasury_market_ticks, primary_key: false) do
      add :id, :uuid, default: fragment("gen_random_uuid()"), null: false
      add :pair, :string, null: false
      add :price, :decimal, null: false
      add :tick_time, :utc_datetime_usec, null: false

      timestamps()
    end

    execute "ALTER TABLE treasury_market_ticks ADD PRIMARY KEY (id, tick_time);"

    execute "SELECT create_hypertable('treasury_market_ticks', 'tick_time', if_not_exists => TRUE);"

    create index(:treasury_market_ticks, [:pair, :tick_time])
  end

  def down do
    drop table(:treasury_market_ticks)
  end
end
