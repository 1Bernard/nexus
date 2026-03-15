defmodule Nexus.Treasury.Projectors.PolicyProjector do
  @moduledoc """
  Projector for Treasury Policies.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.PolicyProjector"

  alias Nexus.Treasury.Events.{
    TransferThresholdSet,
    PolicyAlertTriggered,
    PolicyModeChanged,
    ModeThresholdsConfigured
  }

  alias Nexus.Treasury.Projections.{TreasuryPolicy, PolicyAlert}

  project(%TransferThresholdSet{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :treasury_policy,
      %TreasuryPolicy{
        id: event.policy_id,
        org_id: event.org_id,
        transfer_threshold: parse_decimal(event.threshold)
      },
      on_conflict: {:replace, [:transfer_threshold, :updated_at]},
      conflict_target: [:org_id]
    )
  end)

  project(%PolicyModeChanged{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :treasury_policy,
      %TreasuryPolicy{
        id: event.policy_id,
        org_id: event.org_id,
        mode: event.mode,
        transfer_threshold: parse_decimal(event.threshold)
      },
      on_conflict: {:replace, [:mode, :transfer_threshold, :updated_at]},
      conflict_target: [:org_id]
    )
    |> Ecto.Multi.insert(
      :policy_audit_log,
      %Nexus.Treasury.Projections.PolicyAuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: event.org_id,
        actor_email: event.actor_email,
        mode: event.mode,
        threshold: parse_decimal(event.threshold),
        changed_at: Nexus.Schema.parse_datetime(event.changed_at)
      }
    )
  end)

  project(%ModeThresholdsConfigured{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :treasury_policy,
      %TreasuryPolicy{
        id: event.policy_id,
        org_id: event.org_id,
        mode_thresholds: event.mode_thresholds
      },
      on_conflict: {:replace, [:mode_thresholds, :updated_at]},
      conflict_target: [:org_id]
    )
    |> Ecto.Multi.insert(
      :policy_audit_log,
      %Nexus.Treasury.Projections.PolicyAuditLog{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: event.org_id,
        actor_email: event.actor_email,
        mode: "CONFIG",
        threshold: Decimal.new("0"),
        changed_at: Nexus.Schema.parse_datetime(event.configured_at)
      }
    )
  end)

  project(%PolicyAlertTriggered{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :policy_alert,
      %PolicyAlert{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: event.org_id,
        currency_pair: event.currency_pair,
        exposure_amount: parse_decimal(event.exposure_amount),
        threshold: parse_decimal(event.threshold),
        triggered_at: Nexus.Schema.parse_datetime(event.triggered_at)
      }
    )
  end)

  defp parse_decimal(val), do: Nexus.Schema.parse_decimal(val)
end
