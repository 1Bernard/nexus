defmodule Nexus.Intelligence.Handlers.RealTimeAnalysisHandler do
  @moduledoc """
  Handles real-time PubSub notifications for Intelligence domain events.
  Decoupled from AnalysisProjector (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Intelligence.Handlers.RealTimeAnalysisHandler",
    consistency: :eventual

  alias Nexus.Intelligence.Events.{AnomalyDetected, SentimentScored, AnomalyResolved}

  def handle(%AnomalyDetected{} = event, _metadata) do
    # Note: The projector normally provides the 'analysis' struct in after_update.
    # Since we are decoupled, we broadcast the event itself or the ID.
    # If the UI needs the full projection, it should subscribe to the projector's after_update
    # OR we can keep the projector's after_update if it's strictly for UI sync.
    # HOWEVER, the rule says "Projectors may only write to the DB".
    # So we broadcast here.
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "intelligence:analyses",
      {:analysis_projected, event}
    )

    :ok
  end

  def handle(%SentimentScored{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "intelligence:analyses",
      {:analysis_projected, event}
    )

    :ok
  end

  def handle(%AnomalyResolved{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "intelligence:analyses",
      {:analysis_resolved, event.analysis_id}
    )

    :ok
  end

  def handle(_event, _metadata), do: :ok
end
