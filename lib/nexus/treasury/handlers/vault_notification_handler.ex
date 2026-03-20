defmodule Nexus.Treasury.Handlers.VaultNotificationHandler do
  @moduledoc """
  Handles Vault events and broadcasts updates to Phoenix PubSub.
  """
  use Commanded.Event.Handler,
    application: Nexus.App,
    name: "Treasury.VaultNotificationHandler",
    consistency: :strong

  alias Nexus.Treasury.Events.{VaultRegistered, VaultBalanceSynced, VaultDebited, VaultCredited}

  @spec handle(
          VaultRegistered.t() | VaultBalanceSynced.t() | VaultDebited.t() | VaultCredited.t(),
          map()
        ) :: :ok
  def handle(%VaultRegistered{} = event, _metadata) do
    broadcast(event)
  end

  def handle(%VaultBalanceSynced{} = event, _metadata) do
    broadcast(event)
  end

  def handle(%VaultDebited{} = event, _metadata) do
    broadcast(event)
  end

  def handle(%VaultCredited{} = event, _metadata) do
    broadcast(event)
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(Nexus.PubSub, "vaults", {:vault_event, event})
  end
end
