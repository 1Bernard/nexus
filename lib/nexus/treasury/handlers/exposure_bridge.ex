defmodule Nexus.Treasury.Handlers.ExposureBridge do
  @moduledoc """
  Event Handler that bridges the ERP domain to the Treasury domain.
  Listens for `InvoiceIngested` events and triggers a recalculation of
  FX exposure for the affected subsidiary and currency.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.ExposureBridge",
    consistency: :strong

  require Logger
  alias Nexus.ERP.Events.InvoiceIngested
  alias Nexus.Treasury.Commands.CalculateExposure
  alias Nexus.ERP

  @spec handle(InvoiceIngested.t(), map()) :: :ok
  def handle(%InvoiceIngested{} = event, _metadata) do
    Logger.info(
      "[Treasury] [ExposureBridge] Ingested Invoice detected for #{event.subsidiary} / #{event.currency}. Recalculating exposure..."
    )

    # Note: Consistency is set to :strong for this handler.
    # While InvoiceProjector runs in parallel, ERP.get_total_exposure/3
    # is designed to be eventually accurate or we use a Process Manager.
    # We remove the brittle sleep to follow industry standards.

    # 1. Fetch the new total exposure for this subsidiary/currency
    total_exposure = ERP.get_total_exposure(event.org_id, event.subsidiary, event.currency)

    Logger.info(
      "[Treasury] [ExposureBridge] Calculated Total for #{event.subsidiary}: #{total_exposure}"
    )

    # 2. Dispatch the command to the Treasury aggregate
    command = %CalculateExposure{
      id: "#{event.subsidiary}-#{event.currency}",
      org_id: event.org_id,
      subsidiary: event.subsidiary,
      currency: event.currency,
      exposure_amount: total_exposure,
      timestamp: Nexus.Schema.utc_now()
    }

    Nexus.App.dispatch(command)
  end
end
