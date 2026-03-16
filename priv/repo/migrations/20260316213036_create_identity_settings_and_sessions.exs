defmodule Nexus.Repo.Migrations.CreateIdentitySettingsAndSessions do
  use Ecto.Migration

  def change do
    create table(:identity_user_settings, primary_key: false) do
      add :user_id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :locale, :string, default: "en"
      add :timezone, :string, default: "UTC"
      add :theme, :string, default: "dark"
      add :notifications_enabled, :boolean, default: true, null: false

      timestamps(inserted_at: :created_at)
    end

    create index(:identity_user_settings, [:org_id])
    create index(:identity_user_settings, [:user_id])
    create unique_index(:identity_user_settings, [:user_id, :org_id])

    create table(:identity_user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :session_token, :string, null: false
      add :user_agent, :text
      add :ip_address, :string
      add :last_active_at, :utc_datetime_usec
      add :is_expired, :boolean, default: false, null: false

      timestamps(inserted_at: :created_at)
    end

    create index(:identity_user_sessions, [:org_id])
    create index(:identity_user_sessions, [:user_id])
    create index(:identity_user_sessions, [:session_token])
  end
end
