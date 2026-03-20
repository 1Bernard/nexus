defmodule Nexus.Treasury.Handlers.PolicyNotificationHandler do
  @moduledoc """
  Handles real-time PubSub notifications for Treasury Policy events.
  Decoupled from PolicyProjector (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.Handlers.PolicyNotificationHandler",
    consistency: :eventual

  alias Nexus.Treasury.Events.{PolicyModeChanged, PolicyAlertTriggered}

  @spec handle(PolicyModeChanged.t() | PolicyAlertTriggered.t(), map()) :: :ok
  def handle(%PolicyModeChanged{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "policy_mode:#{event.org_id}",
      {:policy_mode_changed, event}
    )

    :ok
  end

  def handle(%PolicyAlertTriggered{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "policy_alerts:#{event.org_id}",
      {:policy_alert, event}
    )

    :ok
  end

  def handle(_event, _metadata), do: :ok
end
