defmodule Nexus.Repo.Migrations.AddMatchedByToReconciliations do
  use Ecto.Migration

  def change do
    alter table(:treasury_reconciliations) do
      add :actor_email, :string
    end
  end
end
