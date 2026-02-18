defmodule Nexus.Repo.Migrations.IndustrializeUsersTable do
  use Ecto.Migration

  def up do
    # Check if the table exists first (it should)
    alter table(:users) do
      add_if_not_exists :cose_key, :binary
      add_if_not_exists :credential_id, :binary
    end

    # Remove the legacy public_key
    execute "ALTER TABLE users DROP COLUMN IF EXISTS public_key"

    # Drop the strict index that's breaking idempotent projections in dev/test
    execute "DROP INDEX IF EXISTS users_credential_id_index"
  end

  def down do
    alter table(:users) do
      add :public_key, :text
      remove :cose_key
      remove :credential_id
    end
  end
end
