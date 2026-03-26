defmodule Nexus.Treasury.Commands.RebalancePortfolio do
  @moduledoc """
  Command to initiate a portfolio rebalancing check and possible trade suggestions.
  """
  alias Nexus.Types

  @type t :: %__MODULE__{
          portfolio_id: Types.binary_id(),
          org_id: Types.org_id(),
          triggered_by: String.t(),
          metadata: map() | nil
        }

  @enforce_keys [:portfolio_id, :org_id, :triggered_by]
  defstruct [:portfolio_id, :org_id, :triggered_by, :metadata]
end
