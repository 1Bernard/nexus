defmodule Nexus.Treasury.Handlers.ExposurePolicyHandler do
  @moduledoc """
  Event Handler that monitors calculated exposure against defined policies.
  Listens for `ExposureCalculated` and dispatches `EvaluateExposurePolicy`.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.ExposurePolicyHandler",
    consistency: :strong

  require Logger
  alias Nexus.Treasury.Events.ExposureCalculated
  alias Nexus.Treasury.Commands.EvaluateExposurePolicy

  def handle(%ExposureCalculated{} = event, _metadata) do
    # Currency pair for policy evaluation
    pair = "#{event.currency}/USD"

    Logger.info(
      "[Treasury] [PolicyHandler] New exposure calculated for #{event.subsidiary} (#{event.currency}). Evaluating policy..."
    )

    command = %EvaluateExposurePolicy{
      # Assume policy ID is same as Org ID for simplicity
      policy_id: event.org_id,
      org_id: event.org_id,
      currency_pair: pair,
      exposure_amount: event.exposure_amount
    }

    Nexus.App.dispatch(command)
  end
end
