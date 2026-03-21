defmodule Nexus.Repo.Migrations.FixControlDriftsTimestamps do
  use Ecto.Migration

  def change do
    rename table(:reporting_control_drifts), :inserted_at, to: :created_at
  end
end
