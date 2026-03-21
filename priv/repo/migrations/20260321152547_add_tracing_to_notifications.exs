defmodule Nexus.Repo.Migrations.AddTracingToNotifications do
  use Ecto.Migration

  def change do
    alter table(:cross_domain_notifications) do
      add :correlation_id, :binary_id
      add :causation_id, :binary_id
    end

    create index(:cross_domain_notifications, [:correlation_id])
    create index(:cross_domain_notifications, [:causation_id])
  end
end
