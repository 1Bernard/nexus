defmodule Nexus.Reporting.Projectors.TransferPolicyProjector do
  @moduledoc """
  Specialized projector for treasury transfer policies.
  Implements Continuous Control Monitoring (CCM) with drift detection.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Reporting.TransferPolicyProjector",
    repo: Nexus.Repo,
    consistency: :strong

  import Ecto.Query
  alias Nexus.Treasury.Events.TransferThresholdSet
  alias Nexus.Reporting.Projections.{ControlMetric, ControlDrift}

  project(%TransferThresholdSet{} = event, metadata, fn multi ->
    # Elite Rule 9: Type-safe parsing
    new_threshold = Nexus.Schema.parse_decimal(event.threshold)
    id = metadata.event_id

    multi
    |> Ecto.Multi.insert(:"metric_policy_#{id}", %ControlMetric{
      id: id,
      org_id: event.org_id,
      metric_key: "policy_drift",
      score: Decimal.new(1),
      metadata: %{
        threshold: new_threshold,
        causation_id: metadata.causation_id
      }
    })
    |> Ecto.Multi.run(:"detect_drift_#{id}", fn repo, _ ->
      # Detect drift by comparing with previous state
      previous =
        repo.one(
          from d in ControlDrift,
            where: d.org_id == ^event.org_id and d.control_key == "transfer_threshold",
            order_by: [desc: d.last_changed_at],
            limit: 1
        )

      original_value = if previous, do: previous.current_value, else: "0"

      # Calculate drift score (simple percentage change for this POC)
      orig_dec = Nexus.Schema.parse_decimal(original_value)
      drift_score = calculate_drift(orig_dec, new_threshold)

      repo.insert(%ControlDrift{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: event.org_id,
        control_key: "transfer_threshold",
        original_value: original_value,
        current_value: Decimal.to_string(new_threshold),
        drift_score: drift_score,
        last_changed_at: DateTime.utc_now()
      }, on_conflict: :replace_all, conflict_target: [:org_id, :control_key])
    end)
  end)

  defp calculate_drift(orig, new) do
    if Decimal.equal?(orig, Decimal.new(0)) do
      Decimal.new(0)
    else
      # |(new - orig) / orig|
      new
      |> Decimal.sub(orig)
      |> Decimal.div(orig)
      |> Decimal.abs()
      |> Decimal.round(4)
    end
  end
end
