defmodule Nexus.Treasury.Gateways.PolygonClient do
  @moduledoc """
  WebSocket client for ingesting real-time FX market ticks from external providers (e.g. Polygon.io).
  """
  use WebSockex
  require Logger

  alias Nexus.Treasury.Gateways.PriceCache
  alias Nexus.Treasury.Commands.RecordMarketTick

  @default_url "wss://socket.polygon.io/forex"

  def start_link(opts \\ []) do
    url = Keyword.get(opts, :url, @default_url)
    WebSockex.start_link(url, __MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("[Treasury] Connected to Market Data Feed (WebSockex).")
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    # Expected payload format for Demo: {"ev":"C", "pair":"EUR/USD", "p":1.0842, "t":1700000000000}
    with {:ok, payloads} <- Jason.decode(msg) do
      handle_payloads(List.wrap(payloads))
    end

    {:ok, state}
  end

  def handle_frame(_frame, state) do
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

    # 1. Fast path: update ETS cache for O(1) lookups by LiveView
    PriceCache.update_price(pair, price)

    # 2. CQRS path: dispatch command to store tick in TimescaleDB via EventStore
    cmd = %RecordMarketTick{
      pair: pair,
      price: price,
      timestamp: timestamp
    }

    case Nexus.Router.dispatch(cmd) do
      :ok ->
        # Broadcast the event locally to PubSub for immediate UI updates
        Phoenix.PubSub.broadcast(
          Nexus.PubSub,
          "market_ticks:#{pair}",
          {:market_tick, pair, price, timestamp}
        )

      {:error, reason} ->
        Logger.error("[Treasury] Failed to record market tick for #{pair}: #{inspect(reason)}")
    end
  end
end
