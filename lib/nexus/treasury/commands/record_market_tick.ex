defmodule Nexus.Treasury.Commands.RecordMarketTick do
  @moduledoc """
  Command to record a real-time market tick from an FX data provider.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          pair: String.t(),
          price: Types.money(),
          timestamp: Types.datetime()
        }
  @enforce_keys [:pair, :price, :timestamp]
  defstruct [:pair, :price, :timestamp]
end
