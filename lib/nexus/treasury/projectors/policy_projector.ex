defmodule Nexus.Treasury.Projectors.PolicyProjector do
  @moduledoc """
  Projector for Treasury Policies.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.PolicyProjector"

  alias Nexus.Treasury.Events.{TransferThresholdSet, PolicyAlertTriggered, PolicyModeChanged}
  alias Nexus.Treasury.Projections.{TreasuryPolicy, PolicyAlert}

  project(%TransferThresholdSet{} = ev, _metadata, fn multi ->
    Ecto.Multi.insert(
      multi,
      :treasury_policy,
      %TreasuryPolicy{
        id: ev.policy_id,
        org_id: ev.org_id,
        transfer_threshold: parse_decimal(ev.threshold)
      },
      on_conflict: {:replace, [:transfer_threshold, :updated_at]},
      conflict_target: [:org_id]
    )
  end)

  project(%PolicyModeChanged{} = ev, _metadata, fn multi ->
    # Broadcast so DashboardLive can update the active tab in real time
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "policy_mode:#{ev.org_id}",
      {:policy_mode_changed, ev}
    )

    Ecto.Multi.insert(
      multi,
      :treasury_policy,
      %TreasuryPolicy{
        id: ev.policy_id,
        org_id: ev.org_id,
        mode: ev.mode,
        transfer_threshold: parse_decimal(ev.threshold)
      },
      on_conflict: {:replace, [:mode, :transfer_threshold, :updated_at]},
      conflict_target: [:org_id]
    )
  end)

  project(%PolicyAlertTriggered{} = ev, _metadata, fn multi ->
    # Broadcast to PubSub for LiveView updates
    Phoenix.PubSub.broadcast(Nexus.PubSub, "policy_alerts:#{ev.org_id}", {:policy_alert, ev})

    Ecto.Multi.insert(
      multi,
      :policy_alert,
      %PolicyAlert{
        id: Nexus.Schema.generate_uuidv7(),
        org_id: ev.org_id,
        currency_pair: ev.currency_pair,
        exposure_amount: parse_decimal(ev.exposure_amount),
        threshold: parse_decimal(ev.threshold),
        triggered_at: ev.triggered_at
      }
    )
  end)

  defp parse_decimal(val) when is_struct(val, Decimal), do: val
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
end
