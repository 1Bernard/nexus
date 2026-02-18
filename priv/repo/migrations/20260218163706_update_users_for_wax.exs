defmodule Nexus.Repo.Migrations.UpdateUsersForWax do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :public_key
      add :cose_key, :binary
      add :credential_id, :binary
    end

    create unique_index(:users, [:credential_id])
  end
end
