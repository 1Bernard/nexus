defmodule Nexus.Treasury.Projections.PolicyAlert do
  @moduledoc """
  Read model for exposure policy alerts.
  """
  use Nexus.Schema

  schema "treasury_policy_alerts" do
    field :org_id, :binary_id
    field :currency_pair, :string
    field :exposure_amount, :decimal
    field :threshold, :decimal
    field :triggered_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at])
    |> validate_required([:org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at])
  end
end
