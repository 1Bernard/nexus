defmodule Nexus.Repo.Migrations.CreateUsersProjection do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :role, :string
      add :public_key, :text

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:users, [:email])
  end
end
