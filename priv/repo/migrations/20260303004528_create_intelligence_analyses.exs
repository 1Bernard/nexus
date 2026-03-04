defmodule Nexus.Repo.Migrations.CreateIntelligenceAnalyses do
  use Ecto.Migration

  def change do
    create table(:intelligence_analyses, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :org_id, :uuid, null: false
      add :invoice_id, :uuid
      add :source_id, :uuid
      # "anomaly" or "sentiment"
      add :type, :string, null: false
      add :score, :float
      add :sentiment, :string
      add :confidence, :float
      add :reason, :text
      add :flagged_at, :utc_datetime_usec
      add :scored_at, :utc_datetime_usec

      timestamps()
    end

    create index(:intelligence_analyses, [:org_id])
    create index(:intelligence_analyses, [:type])
    create index(:intelligence_analyses, [:invoice_id])
  end
end
