defmodule Nexus.Treasury.Projections.ExposureSnapshot do
  @moduledoc """
  Read model for the latest calculated FX risk exposure per subsidiary and currency.
  Uses a composite string primary key (subsidiary-currency) for fast point lookups.
  """
  # Nexus.Schema provides @foreign_key_type :binary_id and microsecond timestamps.
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :subsidiary, :currency, :exposure_amount, :calculated_at]}
  schema "treasury_exposure_snapshots" do
    field :org_id, :binary_id
    field :subsidiary, :string
    field :currency, :string
    field :exposure_amount, :decimal
    field :calculated_at, :utc_datetime_usec

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:id, :org_id, :subsidiary, :currency, :exposure_amount, :calculated_at])
    |> validate_required([:id, :org_id, :subsidiary, :currency, :exposure_amount, :calculated_at])
  end
end
