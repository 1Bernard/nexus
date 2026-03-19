defmodule Nexus.Repo.Migrations.AddInstitutionalFieldsToVaults do
  use Ecto.Migration

  def change do
    alter table(:treasury_vaults) do
      add :daily_withdrawal_limit, :decimal, precision: 20, scale: 4, default: 0
      add :requires_multi_sig, :boolean, default: false, null: false
    end
  end
end
