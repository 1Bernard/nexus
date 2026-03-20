defmodule Nexus.Treasury.Handlers.TransferNotificationHandler do
  @moduledoc """
  Handles real-time PubSub notifications for Transfer lifecycle events.
  Decoupled from persistence (Rule 3).
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.Handlers.TransferNotificationHandler",
    consistency: :eventual

  alias Nexus.Treasury.Events.{TransferInitiated, TransferAuthorized, TransferExecuted}

  @spec handle(TransferInitiated.t() | TransferAuthorized.t() | TransferExecuted.t(), map()) ::
          :ok
  def handle(%TransferInitiated{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "transfers:#{event.org_id}",
      {:transfer_initiated, event}
    )

    :ok
  end

  def handle(%TransferAuthorized{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "transfers:#{event.org_id}",
      {:transfer_authorized, event}
    )

    :ok
  end

  def handle(%TransferExecuted{} = event, _metadata) do
    Phoenix.PubSub.broadcast(
      Nexus.PubSub,
      "transfers:#{event.org_id}",
      {:transfer_executed, event}
    )

    :ok
  end
end
