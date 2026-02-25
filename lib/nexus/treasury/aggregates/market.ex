defmodule Nexus.Treasury.Aggregates.Market do
  @moduledoc """
  CQRS Aggregate for tracking the latest FX market tick data for a currency pair.
  """
  defstruct [:id, :pair, :last_price, :last_tick_time]

  alias Nexus.Treasury.Commands.RecordMarketTick
  alias Nexus.Treasury.Events.MarketTickRecorded

  @doc """
  Executes the RecordMarketTick command to emit an event.
  """
  def execute(%__MODULE__{} = _state, %RecordMarketTick{} = cmd) do
    %MarketTickRecorded{
      pair: cmd.pair,
      price: cmd.price,
      timestamp: cmd.timestamp || DateTime.utc_now()
    }
  end

  @doc """
  Mutates state based on a MarketTickRecorded event.
  """
  def apply(%__MODULE__{} = state, %MarketTickRecorded{} = event) do
    %{
      state
      | id: event.pair,
        pair: event.pair,
        last_price: event.price,
        last_tick_time: event.timestamp
    }
  end
end
