defmodule Nexus.Reporting.Projections.ControlDrift do
  @moduledoc """
  Read-model schema for the reporting_control_drifts table.
  Tracks deviations in system controls (e.g., threshold changes, role reassignments).
  Essential for Continuous Control Monitoring (CCM).
  """
  use Nexus.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :org_id,
             :control_key,
             :original_value,
             :current_value,
             :drift_score,
             :last_changed_at
           ]}
  schema "reporting_control_drifts" do
    field :org_id, :binary_id
    field :control_key, :string
    field :original_value, :string
    field :current_value, :string
    field :drift_score, :decimal, default: 0
    field :last_changed_at, :utc_datetime_usec

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(drift, attrs) do
    drift
    |> cast(attrs, [
      :id,
      :org_id,
      :control_key,
      :original_value,
      :current_value,
      :drift_score,
      :last_changed_at
    ])
    |> validate_required([:id, :org_id, :control_key, :last_changed_at])
    |> unique_constraint([:org_id, :control_key])
  end
end
