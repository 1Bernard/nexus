defmodule Nexus.Treasury.Projections.PolicyAlert do
  @moduledoc """
  Read model for exposure policy alerts.
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [:org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at]}
  schema "treasury_policy_alerts" do
    field :org_id, :binary_id
    field :currency_pair, :string
    field :exposure_amount, :decimal
    field :threshold, :decimal
    field :triggered_at, :utc_datetime_usec
    field :org_name, :string, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at])
    |> validate_required([:org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at])
  end
end
