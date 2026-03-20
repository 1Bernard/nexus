defmodule Nexus.Treasury.Projections.Forecast do
  @moduledoc """
  Read model for liquidity forecasts.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :currency,
             :horizon_days,
             :predicted_inflow,
             :predicted_outflow,
             :predicted_gap,
             :generated_at
           ]}
  schema "treasury_forecasts" do
    field :org_id, :binary_id
    field :currency, :string
    field :horizon_days, :integer
    field :predicted_inflow, :decimal
    field :predicted_outflow, :decimal
    field :predicted_gap, :decimal
    field :generated_at, :utc_datetime_usec

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(forecast, attrs) do
    forecast
    |> cast(attrs, [
      :org_id,
      :currency,
      :horizon_days,
      :predicted_inflow,
      :predicted_outflow,
      :predicted_gap,
      :generated_at
    ])
    |> validate_required([:org_id, :currency, :horizon_days, :predicted_gap, :generated_at])
  end
end
