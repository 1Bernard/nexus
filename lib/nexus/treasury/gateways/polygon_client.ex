defmodule Nexus.Treasury.Gateways.PolygonClient do
  @moduledoc """
  WebSocket client for ingesting real-time FX market ticks from Massive API.
  Implements a resilient connection strategy that doesn't block the supervision tree.
  """
  use GenServer
  require Logger

  @default_url "wss://socket.massive.com/forex"

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    url = Keyword.get(opts, :url, Application.get_env(:nexus, :massive_url, @default_url))
    api_key = Application.get_env(:nexus, :massive_api_key)

    # Defer connection to prevent blocking the supervision tree
    {:ok, %{url: url, api_key: api_key, socket: nil}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    Logger.info("[Treasury] Initiating background connection to Massive Feed...")

    case __MODULE__.SocketHandler.start_link(state.url, state.api_key) do
      {:ok, pid} ->
        {:noreply, %{state | socket: pid}}

      {:error, reason} ->
        Logger.error(
          "[Treasury] Failed to connect to Massive Feed: #{inspect(reason)}. Retrying in 30s..."
        )

        Process.send_after(self(), :connect, 30_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  # --- Socket Handler Sub-module ---

  defmodule SocketHandler do
    use WebSockex
    require Logger

    alias Nexus.Treasury.Gateways.PriceCache
    alias Nexus.Treasury.Commands.RecordMarketTick

    def start_link(url, api_key) do
      WebSockex.start_link(url, __MODULE__, %{api_key: api_key})
    end

    @impl true
    def handle_connect(_conn, state) do
      Logger.info("[Treasury] WebSocket Connection established. Waiting for server status...")
      {:ok, state}
    end

    @impl true
    def handle_frame({:text, msg}, state) do
      case Jason.decode(msg) do
        {:ok, payloads} ->
          handle_payloads(List.wrap(payloads), state)

        {:error, _reason} ->
          Logger.error("[Treasury] Received invalid JSON from Massive: #{inspect(msg)}")
          {:ok, state}
      end
    end

    defp handle_payloads([], state), do: {:ok, state}

    defp handle_payloads([payload | rest], state) do
      case payload do
        %{"ev" => "status", "status" => "connected"} ->
          Logger.info("[Treasury] Massive Feed connected. Authenticating...")
          auth_msg = Jason.encode!(%{action: "auth", params: state.api_key})
          {:reply, {:text, auth_msg}, state}

        %{"ev" => "status", "status" => "auth_success"} ->
          Logger.info("[Treasury] Massive Authentication successful. Subscribing to CAS.*...")
          sub_msg = Jason.encode!(%{action: "subscribe", params: "CAS.*"})
          {:reply, {:text, sub_msg}, state}

        %{"ev" => "CAS", "pair" => pair, "c" => price, "s" => timestamp_ms} ->
          process_tick(pair, price, timestamp_ms)
          handle_payloads(rest, state)

        %{"ev" => "status", "message" => msg} ->
          Logger.info("[Treasury] Massive Status: #{msg}")
          handle_payloads(rest, state)

        _ ->
          handle_payloads(rest, state)
      end
    end

    defp process_tick(pair, price, timestamp_ms) do
      timestamp = DateTime.from_unix!(timestamp_ms, :millisecond)

      # Convert price to Decimal struct to avoid Ecto type errors
      decimal_price =
        case price do
          p when is_binary(p) -> Decimal.new(p)
          p when is_number(p) -> Decimal.from_float(p * 1.0)
          _ -> Decimal.new("0")
        end

      formatted_price = Decimal.to_string(decimal_price, :normal)

      # 1. Update ETS cache
      PriceCache.update_price(pair, formatted_price)

      # 2. Dispatch command for audit trail
      cmd = %RecordMarketTick{
        pair: pair,
        price: decimal_price,
        timestamp: timestamp
      }

      case Nexus.App.dispatch(cmd) do
        :ok ->
          Phoenix.PubSub.broadcast(
            Nexus.PubSub,
            "market_ticks:#{pair}",
            {:market_tick, pair, formatted_price, timestamp}
          )

        {:error, reason} ->
          Logger.error("[Treasury] Failed to record market tick: #{inspect(reason)}")
      end
    end
  end
end
