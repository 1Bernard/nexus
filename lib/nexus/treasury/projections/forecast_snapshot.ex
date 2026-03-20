defmodule Nexus.Treasury.Projections.ForecastSnapshot do
  @moduledoc """
  Read model for liquidity forecasts.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:id, :org_id, :currency, :horizon_days, :data_points, :generated_at]}
  schema "treasury_forecast_snapshots" do
    field :org_id, :binary_id
    field :currency, :string
    field :horizon_days, :integer
    field :data_points, {:array, :map}
    field :generated_at, :naive_datetime_usec

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :org_id, :currency, :horizon_days, :data_points, :generated_at])
    |> validate_required([:id, :org_id, :currency, :horizon_days, :data_points, :generated_at])
  end
end
