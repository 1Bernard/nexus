defmodule Nexus.Repo.Migrations.AddOrgIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :org_id, :binary_id, null: false
    end

    create index(:users, [:org_id])
  end
end
