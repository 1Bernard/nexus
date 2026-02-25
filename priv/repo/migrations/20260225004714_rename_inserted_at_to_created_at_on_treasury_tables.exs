defmodule Nexus.Repo.Migrations.RenameInsertedAtToCreatedAtOnTreasuryTables do
  use Ecto.Migration

  def change do
    # Align treasury_exposure_snapshots with the Nexus.Schema convention
    # (Nexus.Schema sets @timestamps_opts [inserted_at: :created_at]).
    # This table was migrated before that convention was established.
    rename table(:treasury_exposure_snapshots), :inserted_at, to: :created_at

    # Same fix for treasury_market_ticks — also migrated before the convention.
    rename table(:treasury_market_ticks), :inserted_at, to: :created_at
  end
end
