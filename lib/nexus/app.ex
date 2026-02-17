defmodule Nexus.App do
  use Commanded.Application,
    otp_app: :nexus,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: Nexus.EventStore
    ]
end
