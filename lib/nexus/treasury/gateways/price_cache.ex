defmodule Nexus.Treasury.Gateways.PriceCache do
  @moduledoc """
  O(1) Access for High-Frequency FX Market Ticks.

  In professional FX trading, the dashboard cannot wait for a SQL query.
  LiveView reads directly from this ETS table to refresh at 800ms intervals.
  """
  use GenServer
  require Logger

  @table :market_rates_v3

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec update_price(String.t(), String.t(), atom()) :: boolean()
  def update_price(pair, price, source \\ :unknown) do
    :ets.insert(@table, {pair, price, Nexus.Schema.utc_now(), source})
  end

  @spec get_last_tick(String.t()) ::
          {:ok, {String.t(), DateTime.t(), atom()}} | {:error, :no_data}
  def get_last_tick(pair) do
    result = :ets.lookup(@table, pair)

    case result do
      [{_key, price, at, source}] ->
        {:ok, {price, at, source}}

      [{_key, price, at}] ->
        {:ok, {price, at, :unknown}}

      [] ->
        {:error, :no_data}

      other ->
        Logger.error("[Treasury] [PriceCache] Unexpected result for #{pair}: #{inspect(other)}")
        {:error, :no_data}
    end
  end

  @spec get_price(String.t()) :: {:ok, String.t()} | {:error, :no_data}
  def get_price(pair) do
    case get_last_tick(pair) do
      {:ok, {price, _at, _source}} -> {:ok, price}
      error -> error
    end
  end

  # --- Server Callbacks ---

  @impl true
  @spec init(any()) :: {:ok, map()}
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    Logger.info("[Treasury] ETS Price Cache Initialized")
    {:ok, %{}}
  end
end
