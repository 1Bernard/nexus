defmodule Nexus.Treasury.Events.PortfolioRebalanced do
  @moduledoc """
  Event emitted when a portfolio rebalancing session has yielded trade suggestions or execution.
  """
  alias Nexus.Types
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          portfolio_id: Types.binary_id(),
          org_id: Types.org_id(),
          suggestions: list(),
          rebalanced_at: Types.datetime(),
          triggered_by: String.t()
        }

  defstruct [:portfolio_id, :org_id, :suggestions, :rebalanced_at, :triggered_by]
end
