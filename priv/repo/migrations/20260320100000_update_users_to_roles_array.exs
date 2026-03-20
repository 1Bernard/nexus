defmodule Nexus.Repo.Migrations.UpdateUsersToRolesArray do
  use Ecto.Migration

  def up do
    # 1. Rename role to roles
    rename table(:users), :role, to: :roles

    # 2. Drop the old default first to avoid cast errors
    execute "ALTER TABLE users ALTER COLUMN roles DROP DEFAULT"

    # 3. Change type to array of strings
    execute "ALTER TABLE users ALTER COLUMN roles TYPE varchar[] USING array[roles]::varchar[]"

    # 4. Add new default
    alter table(:users) do
      modify :roles, {:array, :string}, default: [], null: false
    end
  end

  def down do
    alter table(:users) do
      modify :roles, :string, default: "trader", null: true
    end

    rename table(:users), :roles, to: :role
  end
end
