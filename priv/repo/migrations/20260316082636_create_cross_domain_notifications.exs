defmodule Nexus.Repo.Migrations.CreateCrossDomainNotifications do
  use Ecto.Migration

  def change do
    create table(:cross_domain_notifications, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :org_id, :uuid, null: false
      add :user_id, :uuid
      add :type, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :metadata, :map, default: "{}", null: false
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create index(:cross_domain_notifications, [:org_id])
    create index(:cross_domain_notifications, [:user_id])
    create index(:cross_domain_notifications, [:created_at])
  end
end
