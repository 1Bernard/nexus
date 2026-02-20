defmodule Nexus.Repo.Migrations.UpdateUsersRemoveEmailAddDisplayName do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :email, :string
      add :display_name, :string
    end

    # email unique index is automatically removed when the column is dropped
  end
end
