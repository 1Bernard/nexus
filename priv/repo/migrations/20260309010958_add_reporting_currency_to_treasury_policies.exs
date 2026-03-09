defmodule Nexus.Repo.Migrations.AddReportingCurrencyToTreasuryPolicies do
  use Ecto.Migration

  def change do
    alter table(:treasury_policies) do
      add :reporting_currency, :string, default: "USD", null: false
    end
  end
end
