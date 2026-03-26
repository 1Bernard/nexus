defmodule Nexus.Intelligence.Handlers.TreasuryMovementAnalyzer do
  @moduledoc """
  Listens for `TransferExecuted` events from the Treasury context and triggers
  the intelligence pipeline for anomaly detection.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Intelligence.TreasuryMovementAnalyzer"

  alias Nexus.Treasury.Events.TransferExecuted
  alias Nexus.Intelligence.Commands.AnalyzeTreasuryMovement
  require Logger

  @spec handle(TransferExecuted.t(), map()) :: :ok
  def handle(%TransferExecuted{} = event, metadata) do
    Logger.info(
      "[Intelligence] Triggering anomaly detection for treasury transfer #{event.transfer_id}"
    )

    analysis_id = Nexus.Schema.generate_uuidv7()

    command = %AnalyzeTreasuryMovement{
      analysis_id: analysis_id,
      org_id: event.org_id,
      transfer_id: event.transfer_id,
      amount: Decimal.new(event.amount),
      currency: event.from_currency,
      flagged_at: Nexus.Schema.utc_now()
    }

    case Nexus.App.dispatch(command, metadata: metadata) do
      :ok ->
        Logger.info("[Intelligence] [Handler] AnalyzeTreasuryMovement DISPATCHED OK")
        :ok
      {:error, reason} ->
        Logger.error("[Intelligence] [Handler] AnalyzeTreasuryMovement DISPATCH ERROR: #{inspect(reason)}")
        :ok
    end
  end
end
