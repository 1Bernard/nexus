defmodule Nexus.Treasury.Gateways.PolygonClient do
  @moduledoc """
  WebSocket client for ingesting real-time FX market ticks.
  Implements a resilient connection strategy that doesn't block the supervision tree.
  """
  use GenServer
  require Logger

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Commands.RecordMarketTick

  @default_url "wss://socket.polygon.io/forex"

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    url = Keyword.get(opts, :url, @default_url)
    # Defer connection to prevent blocking the supervision tree
    {:ok, %{url: url, socket: nil}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    Logger.info("[Treasury] Initiating background connection to Market Data Feed...")

    case WebSockex.start_link(state.url, __MODULE__, %{}, name: :polygon_websocket) do
      {:ok, pid} ->
        {:noreply, %{state | socket: pid}}

      {:error, reason} ->
        Logger.error(
          "[Treasury] Failed to connect to Market Data: #{inspect(reason)}. Retrying in 30s..."
        )

        Process.send_after(self(), :connect, 30_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  # --- WebSockex Callbacks (as a behavior, though we use it as a standalone process) ---
  # Note: Since we are starting WebSockex as a separate process in start_link,
  # the callbacks below are actually for the WebSockex process, not this GenServer.
  # So we need to separate the modules.

  defmodule SocketHandler do
    use WebSockex
    require Logger

    alias Nexus.Treasury.Gateways.PriceCache
    alias Nexus.Treasury.Commands.RecordMarketTick

    def start_link(url, name) do
      WebSockex.start_link(url, __MODULE__, %{}, name: name)
    end

    @impl true
    def handle_connect(_conn, state) do
      Logger.info("[Treasury] Connected to Market Data Feed.")
      {:ok, state}
    end

    @impl true
    def handle_frame({:text, msg}, state) do
      with {:ok, payloads} <- Jason.decode(msg) do
        handle_payloads(List.wrap(payloads))
      end

      {:ok, state}
    end

    defp handle_payloads(payloads) do
      Enum.each(payloads, fn
        %{"ev" => "C", "pair" => pair, "p" => price, "t" => timestamp_ms} ->
          process_tick(pair, price, timestamp_ms)

        _ ->
          :ok
      end)
    end

    defp process_tick(pair, price, timestamp_ms) do
      timestamp = DateTime.from_unix!(timestamp_ms, :millisecond)
      PriceCache.update_price(pair, price)
      cmd = %RecordMarketTick{pair: pair, price: price, timestamp: timestamp}

      case Nexus.Router.dispatch(cmd) do
        :ok ->
          Phoenix.PubSub.broadcast(
            Nexus.PubSub,
            "market_ticks:#{pair}",
            {:market_tick, pair, price, timestamp}
          )

        {:error, reason} ->
          Logger.error("[Treasury] Failed to record market tick: #{inspect(reason)}")
      end
    end
  end

  # Re-update the GenServer to use the SocketHandler
  @impl true
  def handle_continue(:connect, state) do
    case SocketHandler.start_link(state.url, :polygon_websocket) do
      {:ok, pid} ->
        {:noreply, %{state | socket: pid}}

      {:error, _} ->
        Process.send_after(self(), :connect, 30_000)
        {:noreply, state}
    end
  end
end
