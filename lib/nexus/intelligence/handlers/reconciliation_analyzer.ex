defmodule Nexus.Intelligence.Handlers.ReconciliationAnalyzer do
  @moduledoc """
  Listens for `ReconciliationProposed` events from the Treasury context and triggers
  the intelligence pipeline for anomaly detection.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Intelligence.ReconciliationAnalyzer"

  alias Nexus.Treasury.Events.ReconciliationProposed
  alias Nexus.Intelligence.Commands.AnalyzeReconciliation
  require Logger

  @spec handle(ReconciliationProposed.t(), map()) :: :ok
  def handle(%ReconciliationProposed{} = event, _metadata) do
    Logger.info(
      "[Intelligence] Triggering anomaly detection for reconciliation #{event.reconciliation_id}"
    )

    analysis_id = Nexus.Schema.generate_uuidv7()

    command = %AnalyzeReconciliation{
      analysis_id: analysis_id,
      org_id: event.org_id,
      reconciliation_id: event.reconciliation_id,
      variance: event.variance,
      currency: event.currency,
      flagged_at: Nexus.Schema.utc_now()
    }

    case Nexus.App.dispatch(command) do
      :ok -> :ok
      {:error, reason} ->
        Logger.error("[Intelligence] Failed to dispatch AnalyzeReconciliation: #{inspect(reason)}")
        :ok
    end
  end
end
