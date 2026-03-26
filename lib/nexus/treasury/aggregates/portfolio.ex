defmodule Nexus.Treasury.Aggregates.Portfolio do
  @moduledoc """
  Aggregate for managing risk-adjusted portfolio rebalancing states.
  """
  alias Nexus.Types
  defstruct [:id, :org_id, :last_rebalanced_at]

  @type t :: %__MODULE__{
    id: Types.binary_id() | nil,
    org_id: Types.org_id() | nil,
    last_rebalanced_at: Types.datetime() | nil
  }

  alias Nexus.Treasury.Commands.RebalancePortfolio
  alias Nexus.Treasury.Events.PortfolioRebalanced

  # At this stage, we simply delegate the heavy lifting to the RebalancingEngine service
  # in the execute/2 clause later. For now, we establish the domain boundary.

  @spec execute(t(), RebalancePortfolio.t()) :: struct() | [struct()]
  def execute(%__MODULE__{} = _state, %RebalancePortfolio{} = cmd) do
    suggestions = Nexus.Treasury.Services.RebalancingEngine.calculate(cmd.org_id)

    %PortfolioRebalanced{
      portfolio_id: cmd.portfolio_id,
      org_id: cmd.org_id,
      suggestions: suggestions,
      rebalanced_at: DateTime.utc_now(),
      triggered_by: cmd.triggered_by
    }
  end

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = state, %PortfolioRebalanced{} = event) do
    %{state | id: event.portfolio_id, org_id: event.org_id, last_rebalanced_at: event.rebalanced_at}
  end
end
