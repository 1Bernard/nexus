defmodule Nexus.Treasury.Events.MarketTickRecorded do
  @moduledoc """
  Event emitted when a market tick is recorded for an FX pair.
  """
  @derive Jason.Encoder
  @enforce_keys [:pair, :price, :timestamp]
  defstruct [:pair, :price, :timestamp]
end
