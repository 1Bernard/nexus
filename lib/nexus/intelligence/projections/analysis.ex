defmodule Nexus.Intelligence.Projections.Analysis do
  @moduledoc """
  Read-model schema for the intelligence_analyses table.
  Stores anomaly detection and sentiment scoring results produced by the Intelligence domain.
  """
  use Nexus.Schema

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :invoice_id,
             :source_id,
             :type,
             :score,
             :sentiment,
             :confidence,
             :reason,
             :flagged_at,
             :scored_at
           ]}

  schema "intelligence_analyses" do
    field :org_id, :binary_id
    field :invoice_id, :binary_id
    field :source_id, :string
    field :type, :string
    field :score, :float
    field :sentiment, :string
    field :confidence, :float
    field :reason, :string
    field :flagged_at, :utc_datetime_usec
    field :scored_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [
      :id,
      :org_id,
      :invoice_id,
      :source_id,
      :type,
      :score,
      :sentiment,
      :confidence,
      :reason,
      :flagged_at,
      :scored_at
    ])
    |> validate_required([:id, :org_id, :type])
  end
end
