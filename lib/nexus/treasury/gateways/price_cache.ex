defmodule Nexus.Treasury.Gateways.PriceCache do
  @moduledoc """
  O(1) Access for High-Frequency FX Market Ticks.

  In professional FX trading, the dashboard cannot wait for a SQL query.
  LiveView reads directly from this ETS table to refresh at 800ms intervals.
  """
  use GenServer
  require Logger

  @table :market_rates

  # --- Client API ---

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def update_price(pair, price) do
    :ets.insert(@table, {pair, price, DateTime.utc_now()})
  end

  def get_price(pair) do
    case :ets.lookup(@table, pair) do
      [{^pair, price, _at}] -> {:ok, price}
      [] -> {:error, :no_data}
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    Logger.info("[Treasury] ETS Price Cache Initialized")
    {:ok, %{}}
  end
end
