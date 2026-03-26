defmodule Nexus.Repo.Migrations.AddIdToUserSettings do
  use Ecto.Migration

  def change do
    alter table(:identity_user_settings) do
      add :id, :binary_id
    end
    
    # We don't make it primary key here to avoid complex alter table on some DBs,
    # but Ecto will use it as the PK in the projection.
  end
end
