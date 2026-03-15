defmodule Nexus.Treasury.Events.PolicyAlertTriggered do
  @moduledoc """
  Emitted when an exposure calculation exceeds the prescribed threshold.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          currency_pair: String.t(),
          exposure_amount: Types.money(),
          threshold: Types.money(),
          triggered_at: Types.datetime()
        }
  @derive Jason.Encoder
  @enforce_keys [:policy_id, :org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at]
  defstruct [:policy_id, :org_id, :currency_pair, :exposure_amount, :threshold, :triggered_at]
end
