defmodule Nexus.Repo.Migrations.FixIntelligenceAnalysesTimestamps do
  use Ecto.Migration

  def change do
    # In Nexus.Schema, inserted_at is globally renamed to created_at.
    # The original migration for intelligence_analyses used default timestamps().
    # This migration aligns the table with the Nexus standard.
    rename table(:intelligence_analyses), :inserted_at, to: :created_at
  end
end
