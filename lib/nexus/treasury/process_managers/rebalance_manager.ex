defmodule Nexus.Treasury.ProcessManagers.RebalanceManager do
  @moduledoc """
  Saga to automate treasury rebalancing based on liquidity forecasts.
  If a deficit is predicted, it initiates a transfer from a surplus vault.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: "Treasury.RebalanceManager"

  @derive Jason.Encoder
  defstruct [:org_id, :target_currency, :deficit_amount, :completed]

  alias Nexus.Treasury.Events.{ForecastGenerated, TransferInitiated}
  alias Nexus.Treasury.Commands.RequestTransfer
  alias Nexus.Treasury.Queries.VaultQuery
  require Logger

  # 1. Start on forecast generation
  def interested?(%ForecastGenerated{org_id: org_id, currency: curr}), do: {:start, "#{org_id}-#{curr}"}
  # 2. Continue on transfer initiation to track progress (optional for this POC)
  def interested?(%TransferInitiated{org_id: org_id, from_currency: curr}), do: {:continue, "#{org_id}-#{curr}"}
  def interested?(_event), do: false

  # --- Command Dispatch ---

  def handle(%__MODULE__{} = _saga, %ForecastGenerated{} = event) do
    # Simple logic: If any prediction is negative, we have a deficit
    total_prediction =
      event.predictions
      |> Enum.map(&Nexus.Schema.parse_decimal(&1["amount"] || &1[:amount]))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    if Decimal.lt?(total_prediction, 0) do
      Logger.info("[Treasury] [Rebalance] Deficit detected for #{event.currency}: #{total_prediction}")
      initiate_rebalance(event.org_id, event.currency, Decimal.abs(total_prediction))
    else
      []
    end
  end

  def handle(%__MODULE__{}, %TransferInitiated{}), do: []

  defp initiate_rebalance(org_id, target_currency, amount) do
    # Find a source vault with a different currency (e.g. "EUR" to "USD" rebalance)
    # In a real app, this would be more complex hedging logic.
    source_currency = if target_currency == "USD", do: "EUR", else: "USD"

    # Check if we have a vault for the source currency
    case VaultQuery.find_vault_for_currency(org_id, source_currency) do
      nil ->
        Logger.warning("[Treasury] [Rebalance] No source vault found for #{source_currency}")
        []

      vault ->
        # Dispatch the RequestTransfer command to Treasury
        transfer_id = "rebalance-#{org_id}-#{Nexus.Schema.generate_uuidv7()}"

        [
          %RequestTransfer{
            transfer_id: transfer_id,
            org_id: org_id,
            user_id: "system-rebalance",
            from_currency: source_currency,
            to_currency: target_currency,
            amount: amount,
            recipient_data: %{type: "vault", vault_id: vault.id},
            requested_at: Nexus.Schema.utc_now()
          }
        ]
    end
  end

  # --- State Transitions ---

  def apply(%__MODULE__{} = saga, %ForecastGenerated{} = event) do
    %__MODULE__{saga | org_id: event.org_id, target_currency: event.currency}
  end

  def apply(%__MODULE__{} = saga, %TransferInitiated{} = _event) do
    %__MODULE__{saga | completed: true}
  end

  def apply(%__MODULE__{} = saga, _event), do: saga

  # --- Stop Condition ---

  def stop?(%__MODULE__{completed: true}), do: true
  def stop?(_), do: false
end
