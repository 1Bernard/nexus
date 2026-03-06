defmodule Nexus.Repo.Migrations.ChangeAnalysisSourceIdToString do
  use Ecto.Migration

  def change do
    alter table(:intelligence_analyses) do
      modify :source_id, :text, from: :uuid
    end
  end
end
