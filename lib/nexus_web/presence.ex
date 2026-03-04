defmodule NexusWeb.Presence do
  @moduledoc """
  Provides real-time presence tracking for users within organizations.
  """
  use Phoenix.Presence,
    otp_app: :nexus,
    pubsub_server: Nexus.PubSub
end
