defmodule Nexus.Repo.Migrations.AddCompositeIndexToVaults do
  use Ecto.Migration

  def change do
    create index(:treasury_vaults, [:org_id, :currency])
  end
end
