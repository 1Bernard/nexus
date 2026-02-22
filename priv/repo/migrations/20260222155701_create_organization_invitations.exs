defmodule Nexus.Repo.Migrations.CreateOrganizationInvitations do
  use Ecto.Migration

  def change do
    create table(:organization_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :email, :string, null: false
      add :role, :string, null: false
      add :invited_by, :string, null: false
      add :invitation_token, :binary_id, null: false
      add :status, :string, null: false, default: "pending"
      add :invited_at, :utc_datetime_usec, null: false
      add :claimed_at, :utc_datetime_usec

      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:organization_invitations, [:org_id])
    create unique_index(:organization_invitations, [:email, :org_id])
    create unique_index(:organization_invitations, [:invitation_token])
  end
end
