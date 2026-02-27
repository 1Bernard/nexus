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

  def handle(%InvoiceIngested{} = event, _metadata) do
    Logger.info(
      "[Treasury] [ExposureBridge] Ingested Invoice detected for #{event.subsidiary} / #{event.currency}. Recalculating exposure..."
    )

    # Wait briefly for the InvoiceProjector to finish writing to the read model
    # (In a real system, we might use a Process Manager or consistency guarantees)
    Process.sleep(500)

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
      timestamp: DateTime.utc_now()
    }

    Nexus.App.dispatch(command)
  end
end
