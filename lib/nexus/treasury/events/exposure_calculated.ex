defmodule Nexus.Treasury.Events.ExposureCalculated do
  @moduledoc """
  Event emitted when FX risk exposure is calculated for a subsidiary.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          org_id: Types.org_id(),
          subsidiary: String.t(),
          currency: Types.currency(),
          exposure_amount: Types.money(),
          timestamp: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
  defstruct [:org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
end
