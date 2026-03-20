defmodule Nexus.Repo.Migrations.UpdateInvitationsToRolesArray do
  use Ecto.Migration

  def up do
    # Drop the default if it exists to avoid type mismatch during alter
    execute "ALTER TABLE organization_invitations ALTER COLUMN role DROP DEFAULT"

    # Alter column to array
    execute "ALTER TABLE organization_invitations ALTER COLUMN role TYPE varchar[] USING array[role]"

    # Rename for consistency
    rename table(:organization_invitations), :role, to: :roles

    # Set new default
    alter table(:organization_invitations) do
      modify :roles, {:array, :string}, default: []
    end
  end

  def down do
    rename table(:organization_invitations), :roles, to: :role

    execute "ALTER TABLE organization_invitations ALTER COLUMN role TYPE varchar USING role[1]"

    alter table(:organization_invitations) do
      modify :role, :string, default: "trader"
    end
  end
end
