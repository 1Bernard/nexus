defmodule Nexus.Reporting.Projections.ControlMetric do
  @moduledoc """
  Read-model schema for the reporting_control_metrics table.
  Tracks real-time compliance scores and audit readiness metrics.
  """
  use Nexus.Schema

  schema "reporting_control_metrics" do
    field :org_id, :binary_id
    field :metric_key, :string
    field :score, :decimal
    field :metadata, :map

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :org_id, :metric_key, :score, :metadata])
    |> validate_required([:id, :org_id, :metric_key])
    |> unique_constraint([:org_id, :metric_key])
  end
end
