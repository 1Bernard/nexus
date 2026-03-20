defmodule Nexus.Treasury.Commands.EvaluateExposurePolicy do
  @moduledoc """
  Command to evaluate current exposure against an organization's threshold.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          policy_id: Types.binary_id(),
          org_id: Types.org_id(),
          currency_pair: Types.currency(),
          exposure_amount: Types.money(),
          evaluated_at: Types.datetime()
        }

  @enforce_keys [:policy_id, :org_id, :currency_pair, :exposure_amount, :evaluated_at]
  defstruct [:policy_id, :org_id, :currency_pair, :exposure_amount, :evaluated_at]
end
