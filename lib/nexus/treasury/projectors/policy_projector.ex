defmodule Nexus.Treasury.Projectors.PolicyProjector do
  @moduledoc """
  Projector for Treasury Policies.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    repo: Nexus.Repo,
    name: "Treasury.PolicyProjector"

  alias Nexus.Treasury.Events.TransferThresholdSet
  alias Nexus.Treasury.Projections.TreasuryPolicy

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

  defp parse_decimal(val) when is_struct(val, Decimal), do: val
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
end
