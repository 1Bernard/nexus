defmodule Nexus.Treasury.Commands.RecordMarketTick do
  @moduledoc """
  Command to record a real-time market tick from an FX data provider.
  """
  @enforce_keys [:pair, :price, :timestamp]
  defstruct [:pair, :price, :timestamp]
end
