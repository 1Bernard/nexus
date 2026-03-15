defmodule Nexus.Treasury.Commands.CalculateExposure do
  @moduledoc """
  Command to record a calculated risk exposure for a given subsidiary.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          id: Types.binary_id(),
          org_id: Types.org_id(),
          subsidiary: String.t(),
          currency: Types.currency(),
          exposure_amount: Types.money(),
          timestamp: Types.datetime()
        }
  @enforce_keys [:id, :org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
  defstruct [:id, :org_id, :subsidiary, :currency, :exposure_amount, :timestamp]
end
