defmodule Nexus.Treasury.ProcessManagers.PortfolioManager do
  @moduledoc """
  Coordinates the Portfolio Rebalancing lifecycle.
  Listens for liquidity changes and triggers optimization checks.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.PortfolioManager"

  alias Nexus.Treasury.Events.PortfolioRebalanced

  alias Nexus.Types
  @derive Jason.Encoder
  defstruct [:id, :org_id, :status]

  @type t :: %__MODULE__{
    id: Types.binary_id() | nil,
    org_id: Types.org_id() | nil,
    status: :rebalanced | nil
  }

  # For now, we manually trigger rebalancing via the dashboard,
  # but in production, this would also react to MarketTickRecorded
  # to detect drift automatically.

  @spec interested?(struct()) :: {:start, String.t()} | false
  def interested?(%PortfolioRebalanced{} = event), do: {:start, event.portfolio_id}
  def interested?(_event), do: false

  @spec handle(t(), struct()) :: list()
  def handle(%__MODULE__{}, %PortfolioRebalanced{} = _event) do
    # Placeholder for follow-up actions like sending notifications
    []
  end

  @spec apply(t(), struct()) :: t()
  def apply(%__MODULE__{} = pm, %PortfolioRebalanced{} = event) do
    %{pm | id: event.portfolio_id, org_id: event.org_id, status: :rebalanced}
  end
end
