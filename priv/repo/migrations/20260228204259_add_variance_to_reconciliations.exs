defmodule Nexus.Repo.Migrations.AddVarianceToReconciliations do
  use Ecto.Migration

  def change do
    alter table(:treasury_reconciliations) do
      add :variance, :decimal, default: 0.0, precision: 18, scale: 6
      add :variance_reason, :string
    end
  end
end
