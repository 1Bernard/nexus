defmodule Nexus.Treasury.Handlers.NettingScannerHandler do
  @moduledoc """
  Event handler that triggers the NettingScanner service when a scan is initiated.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.NettingScannerHandler",
    consistency: :strong

  require Logger
  alias Nexus.Treasury.Events.NettingCycleScanInitiated
  alias Nexus.Treasury.Services.NettingScanner

  @spec handle(NettingCycleScanInitiated.t(), map()) :: :ok
  def handle(%NettingCycleScanInitiated{} = event, _metadata) do
    Logger.info("[NettingScannerHandler] Reacting to scan initiation for: #{event.netting_id}")

    case NettingScanner.scan(event.netting_id, event.org_id, event.user_id) do
      {:ok, count} ->
        Logger.info("[NettingScannerHandler] Successfully finished scan. Found #{count} invoices.")
        :ok
      {:error, reason} ->
        Logger.error("[NettingScannerHandler] Scan failed: #{inspect(reason)}")
        # In a real system, we'd emit a ScanFailed event.
        :ok
    end
  end
end
