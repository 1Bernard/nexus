defmodule Nexus.Treasury.Events.MarketTickRecorded do
  @moduledoc """
  Event emitted when a market tick is recorded for an FX pair.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          pair: String.t(),
          price: Types.money(),
          timestamp: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:pair, :price, :timestamp]
  defstruct [:pair, :price, :timestamp]
end
