defmodule Nexus.Repo.Migrations.CreateExposureSnapshots do
  use Ecto.Migration

  def change do
    create table(:treasury_exposure_snapshots, primary_key: false) do
      add :id, :string, primary_key: true
      add :org_id, :string, null: false
      add :subsidiary, :string, null: false
      add :currency, :string, null: false
      add :exposure_amount, :decimal, null: false
      add :calculated_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create index(:treasury_exposure_snapshots, [:org_id])
    create index(:treasury_exposure_snapshots, [:subsidiary, :currency])
  end
end
