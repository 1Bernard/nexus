defmodule Nexus.Repo.Migrations.AddRoleDefaultToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :role, :string, default: "trader", null: false
    end
  end
end
