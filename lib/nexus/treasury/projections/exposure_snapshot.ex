defmodule Nexus.Treasury.Projections.ExposureSnapshot do
  @moduledoc """
  Ecto schema for tracking calculated FX risk exposure per subsidiary.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "treasury_exposure_snapshots" do
    field :org_id, :binary_id
    field :subsidiary, :string
    field :currency, :string
    field :exposure_amount, :decimal
    field :calculated_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:id, :org_id, :subsidiary, :currency, :exposure_amount, :calculated_at])
    |> validate_required([:id, :org_id, :subsidiary, :currency, :exposure_amount, :calculated_at])
  end
end
