defmodule Nexus.App do
  @moduledoc """
  The Commanded application for Nexus.
  """
  use Commanded.Application,
    otp_app: :nexus,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: Nexus.EventStore
    ]
end
